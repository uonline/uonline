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

if process.env.NODE_ENV is 'production'
	console.log 'Loading New Relic...'
	newrelic = require 'newrelic'
	console.log 'Loaded New Relic.'

config = require "#{__dirname}/config.js"
lib = require "#{__dirname}/lib.coffee"

chalk = require 'chalk'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'async'
express = require 'express'
cachify = require 'connect-cachify'
sync = require 'sync'


# Connect to database
dbConnection = anyDB.createPool config.DATABASE_URL, min: 2, max: 20
dbConnection.query 'SELECT version()', [], (error, result) ->
	if error?
		console.log "Problem with database: #{error.stack}"
	else
		console.log "Database: #{result.rows[0].version}"

# Attach profiler?
if process.env.SQLPROF is 'true'
	dbConnection._query = dbConnection.query
	dbConnection.query = (q, data, cb) ->
		logged = q
		for value, index in data
			index++
			while logged.indexOf("$#{index}") isnt -1
				logged = logged.replace "$#{index}", chalk.blue(JSON.stringify(value))
		start = Date.now()
		@_query q, data, (error, result) ->
			time = Date.now() - start
			time = switch
				when time < 10 then chalk.green("#{time} ms")
				when time < 20 then chalk.yellow("#{time} ms")
				else chalk.red("#{time} ms")
			console.log "\n#{time}: #{logged}\n"
			# console.log "\n#{time}: t: #{logged}\n"
			if cb? then cb(error, result)


# Set up Express

app = express()
app.enable 'trust proxy'
app.use express.logger()
app.use express.cookieParser()
app.use express.json()
app.use express.urlencoded()
app.use express.compress()

assets =
	'/assets/scripts.js': [
		'/static/bower_components/jquery/dist/jquery.min.js'
		'/static/bower_components/bootstrap/dist/js/bootstrap.min.js'
		'/static/bower_components/jquery-pjax/jquery.pjax.js'
		'/static/browserified/bundle.min.js'
	]

app.use(cachify.setup(assets,
	root: __dirname
	url_to_paths: {}
	production: process.env.NODE_ENV is 'production'
))

app.use '/assets', express.static "#{__dirname}/assets"
app.use '/static/browserified', express.static "#{__dirname}/browserified"
app.use '/static/bower_components', express.static "#{__dirname}/bower_components"

app.set 'view engine', 'jade'
app.locals.pretty = true
app.set 'views', "#{__dirname}/views"

if newrelic?
	app.locals.newrelic = newrelic


# Middlewares

mustBeAuthed = (request, response, next) ->
	if request.uonline.basicOpts.loggedIn is true
		next()
	else
		response.redirect '/login/'

mustNotBeAuthed = (request, response, next) ->
	if request.uonline.basicOpts.loggedIn is true
		response.redirect config.defaultInstanceForUsers
	else
		next()


app.use ((request, response) ->
	# Read basic stuff
	sessionData = lib.user.sessionInfoRefreshing.sync(null,
		dbConnection, request.cookies.sessid, config.sessionExpireTime, true)
	request.uonline =
		basicOpts:
			now: new Date()
			pjax: request.header('X-PJAX')?
			loggedIn: sessionData.sessionIsActive
			username: sessionData.username
			admin: sessionData.admin
			userid: sessionData.userid
	# CSP
	response.header 'Content-Security-Policy-Report-Only', "default-src 'self'"
	# Anti-clickjacking
	response.header 'X-Frame-Options', 'DENY'
	# Necessary, or it will pass shit to callback
	return
).asyncMiddleware()


# Trivial pages

quickRender = (template) ->
	(request, response) ->
		options = request.uonline.basicOpts
		options.instance = template
		response.render template, options


app.get '/node/', (request, response) ->
	response.send 'Node.js is up and running.'


app.get '/explode/', (request, response) ->
	throw new Error 'Emulated error.'


app.get '/', (request, response) ->
	if request.uonline.basicOpts.loggedIn is true
		response.redirect config.defaultInstanceForUsers
	else
		response.redirect config.defaultInstanceForGuests


app.get '/about/', quickRender 'about'
app.get '/register/', mustNotBeAuthed, quickRender 'register'
app.get '/login/', mustNotBeAuthed, quickRender 'login'


# And the rest

app.post '/register/', mustNotBeAuthed, (request, response) ->
	options = request.uonline.basicOpts
	options.instance = 'register'
	usernameIsValid = lib.validation.usernameIsValid(request.body.user)
	passwordIsValid = lib.validation.passwordIsValid(request.body.pass)
	userExists = lib.user.userExists.sync(null, dbConnection, request.body.user)
	if (usernameIsValid is true) and (passwordIsValid is true) and (userExists is false)
		result = lib.user.registerUser.sync(
			null
			dbConnection
			request.body.user
			request.body.pass
			'user'
		)
		response.cookie 'sessid', result.sessid
		response.redirect '/'
	else
		options.error = true
		options.invalidLogin = !usernameIsValid
		options.invalidPass = !passwordIsValid
		options.loginIsBusy = userExists
		options.user = request.body.user
		options.pass = request.body.pass
		response.render 'register', options


app.post '/login/', mustNotBeAuthed, (request, response) ->
	if lib.user.accessGranted.sync null, dbConnection, request.body.user, request.body.pass
		sessid = lib.user.createSession.sync null, dbConnection, request.body.user
		response.cookie 'sessid', sessid
		response.redirect '/'
	else
		options = request.uonline.basicOpts
		options.instance = 'login'
		options.error = true
		options.user = request.body.user
		response.render 'login', options


app.get '/profile/', mustBeAuthed, (request, response) -> sync ->
	options = request.uonline.basicOpts
	options.instance = 'profile'
	options.username = request.uonline.basicOpts.username
	options.profileIsMine = true
	options.id = request.uonline.basicOpts.userid
	chars = lib.game.getUserCharacters.sync null, dbConnection, request.uonline.basicOpts.userid
	for i of chars
		options[i] = chars[i]
	response.render 'profile', options


app.get '/profile/:username/', (request, response) ->
	username = request.param('username')
	chars = lib.game.getUserCharacters.sync null, dbConnection, username
	if chars is null
		throw new Error '404'
	options = request.uonline.basicOpts
	options.instance = 'profile'
	options.profileIsMine = (options.loggedIn is true) and (chars.id == options.userid)
	for i of chars
		options[i] = chars[i]
	options.username = username
	response.render 'profile', options


app.get '/action/logout', mustBeAuthed, (request, response) ->
	# TODO: move sessid to uonline{}
	lib.user.closeSession dbConnection, request.cookies.sessid, (error, result) ->
		if error?
			response.send 500
		else
			response.redirect '/'


app.get '/game/', mustBeAuthed, (request, response) -> sync ->
	userid = request.uonline.basicOpts.userid
	options = request.uonline.basicOpts
	options.instance = 'game'

	try
		location = lib.game.getUserLocation.sync null, dbConnection, userid
	catch e
		console.error e.stack
		location = lib.game.getInitialLocation.sync null, dbConnection
		lib.game.changeLocation.sync null, dbConnection, userid, location.id

	area = lib.game.getUserArea.sync null, dbConnection, userid
	options.location_name = location.title
	options.area_name = area.title
	options.pic = options.picture  if options.picture?
	options.description = location.description
	options.ways = location.ways
	tmpUsers = lib.game.getNearbyUsers.sync null,
		dbConnection, userid, location.id
	options.players_list = tmpUsers
	tmpMonsters = lib.game.getNearbyMonsters.sync null, dbConnection, location.id
	options.monsters_list = tmpMonsters
	options.fight_mode = lib.game.isInFight.sync null, dbConnection, userid
	options.autoinvolved_fm = lib.game.isAutoinvolved.sync null, dbConnection, userid

	if options.fight_mode
		options.participants = lib.game.getBattleParticipants.sync null, dbConnection, userid
		options.our_side = options.participants.find((p) -> p.kind=='user' && p.id==userid).side

	chars = lib.game.getUserCharacters.sync null, dbConnection, request.uonline.basicOpts.userid
	for i of chars
		options[i] = chars[i]

	response.header 'X-PJAX-URL', '/game/'
	response.render 'game', options


app.get '/inventory/', mustBeAuthed, (request, response) ->
	userid = request.uonline.basicOpts.userid
	options = request.uonline.basicOpts
	options.instance = 'inventory'
	options.fight_mode = lib.game.isInFight.sync null, dbConnection, userid
	response.render 'inventory', options


app.get '/action/go/:to', mustBeAuthed, (request, response) ->
	userid = request.uonline.basicOpts.userid
	to = request.param('to')

	unless lib.game.isInFight.sync null, dbConnection, userid
		if lib.game.canChangeLocation.sync null, dbConnection, userid, to
			lib.game.changeLocation.sync null, dbConnection, userid, to

	response.redirect '/game/'


app.get '/action/attack', mustBeAuthed, (request, response) ->
	lib.game.goAttack.sync null, dbConnection, request.uonline.basicOpts.userid
	response.redirect '/game/'


app.get '/action/escape', mustBeAuthed, (request, response) ->
	lib.game.goEscape.sync null, dbConnection, request.uonline.basicOpts.userid
	response.redirect '/game/'


app.get '/ajax/isNickBusy/:nick', (request, response) ->
	response.json
		nick: request.param('nick')
		isNickBusy: lib.user.userExists.sync null, dbConnection, request.param('nick')


# 404 handling
app.get '*', (request, response) ->
	throw new Error '404'


# Exception handling
app.use (error, request, response, next) ->
	code = if error.message is '404' then 404 else 500
	options = request.uonline.basicOpts
	options.code = code
	options.instance = 'error'
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
