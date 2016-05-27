#!/usr/bin/env coffee

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


'use strict'

if process.env.NEW_RELIC_LICENSE_KEY?
	console.log 'Loading New Relic...'
	newrelic = require 'newrelic'
	console.log 'Loaded New Relic.'

config = require "#{__dirname}/config"
lib = require "#{__dirname}/lib.coffee"

chalk = require 'chalk'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
express = require 'express'
autostatic = require 'autostatic'
sugar = require 'sugar'
{async, await} = require 'asyncawait'
promisifyAll = require("bluebird").promisifyAll
moment = require 'moment'
moment.locale 'ru'


inspect = (x) ->
	console.log require('util').inspect x, depth: null


# Connect to database
dbConnection = promisifyAll anyDB.createPool config.DATABASE_URL, min: 2, max: 20
dbConnection.query 'SELECT version()', [], (error, result) ->
	if error?
		console.log "Problem with database: #{error.stack}"
	else
		console.log "Database: #{result.rows[0].version}"


# Attach profiler?
if process.env.SQLPROF is 'true'
	dbConnection.on 'query', (query) ->
		start = process.hrtime()
		query.on 'close', ->
			timetuple = process.hrtime(start)
			time = Math.round(timetuple[0]*1000 + timetuple[1]/1000000)
			time = switch
				when time < 10 then chalk.green("#{time} ms")
				when time < 20 then chalk.yellow("#{time} ms")
				else chalk.red("#{time} ms")
			logged = query.text
			for value, index in query.values
				index++
				while logged.indexOf("$#{index}") isnt -1
					logged = logged.replace "$#{index}", chalk.blue(JSON.stringify(value))
			console.log " #{time}: #{logged}"


# Set up Express

app = express()
app.enable 'trust proxy'

# logger
morgan = require 'morgan'
morgan.token 'coloredStatus', (req, res) ->
	color = (x) -> x
	status = res.statusCode
	if status >= 200 and status < 300 then color = chalk.green
	if status >= 300 and status < 400 then color = chalk.blue
	if status >= 400 and status < 500 then color = chalk.yellow
	if status >= 500 and status < 600 then color = chalk.red
	return color(status)
morgan.token 'uu', (req, res) ->
	name = req.uonline?.user?.username or '-'
	return chalk.gray(name)
app.use morgan ":remote-addr :uu  :coloredStatus :method :url  #{chalk.gray '":user-agent"'}  :response-time ms"

# middlewares
app.use(require('cookie-parser')())
app.use(require('body-parser').urlencoded(extended: false))
app.use(require('multer')().fields([]))
app.use(require('compression')())

# Hashing static files
as = autostatic(dir: __dirname)
app.use(as.middleware())
app.locals.as = as.helper()

# Expose static paths
app.use '/assets', express.static "#{__dirname}/assets", maxAge: '7 days'
app.use '/bower_components', express.static "#{__dirname}/bower_components", maxAge: '7 days'

# Jade
app.set 'view engine', 'jade'
app.locals.pretty = true
app.set 'views', "#{__dirname}/views"

# expose New Relic
if newrelic?
	app.locals.newrelic = newrelic

# Hallway middleware
app.use lib.middlewares.hallway(moment, dbConnection)

# Pages
routeMatched = (request, response, next) ->
	request.routeMatched = true
	next()

for filename in require('fs').readdirSync("#{__dirname}/routes")
	if not filename.endsWith('.coffee')
		continue
	routes = require "#{__dirname}/routes/#{filename}"
	for path of routes
		for method of routes[path]
			chain = routes[path][method]
			if chain instanceof Function
				chain = [chain]
			for mw, i in chain
				unless typeof mw is 'function'
					throw new Error("wrong middleware ##{i} '#{mw}' for route #{method}:#{path}")

			# wrapping
			chain.forEach (mw, i) ->
				chain[i] = switch
					# it is result of `async((req, res) -> ...)`,
					# should always return promise
					# TODO: fix when native async/await will be ready
					when mw.prototype.constructor.name == 'f2'
						(req, res, next) -> mw(req, res).then((-> next()), next)
					# simple `(req, res, next) -> ...` function,
					# assume it will call `next` inside
					when mw.length == 3
						mw
					# other cases,
					# funtion should return thenable if it is asyncronous
					# or something else if syncronous
					else
						(request, response, next) ->
							result = mw(request, response)
							if typeof result?.then is 'function'
								result.then((-> next()), next)
							else
								next()
							return

			chain.unshift(routeMatched)
			app[method] path, chain


# 404 handling, transaction checking
app.all '*', (request, response, next) ->
	if request.uonline.db.state? and request.uonline.db.state() isnt 'closed'
		throw new Error 'transaction not closed'
	unless request.routeMatched
		throw new Error '404'
	next()


# Exception handling
app.use (error, request, response, next) ->
	if request.uonline.db.state? and request.uonline.db.state() isnt 'closed'
		request.uonline.db.rollback()
	code = 500
	if error.message is '404'
		code = 404
	else
		console.error error.stack
	options = request.uonline
	options.code = code
	options.instance = 'error'
	unless response.headersSent
		response.status code
		response.render 'error', options


# main

DEFAULT_PORT = 5000
port = process.env.PORT or process.env.OPENSHIFT_NODEJS_PORT or DEFAULT_PORT
ip = process.env.OPENSHIFT_NODEJS_IP or process.env.IP or undefined
console.log "Starting up on port #{port}, and IP is #{ip}"

startupFinished = ->
	console.log "Listening on port #{port}"
	if port is DEFAULT_PORT then console.log "Try http://localhost:#{port}/"

if ip?
	app.listen port, ip, startupFinished
else
	app.listen port, startupFinished
