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

config = require "#{__dirname}/config.js"
lib = require "#{__dirname}/lib.coffee"

chalk = require 'chalk'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'async'
express = require 'express'
cachify = require 'connect-cachify'
sync = require 'sync'
sugar = require 'sugar'


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

# logger
morgan = require 'morgan'
morgan.token 'coloredStatus', (req, res) ->
	color = (x) -> x
	status = res.statusCode
	if status >= 200 and status <= 300 then color = chalk.green
	if status >= 300 and status <= 400 then color = chalk.blue
	if status >= 400 and status <= 500 then color = chalk.yellow
	if status >= 500 and status <= 600 then color = chalk.red
	return color(status)
morgan.token 'uu', (req, res) ->
	name = req.uonline?.username or '-'
	return chalk.gray(name)
app.use morgan ":remote-addr :uu  :coloredStatus :method :url  #{chalk.gray '":user-agent"'}  :response-time ms"

app.use express.cookieParser()
app.use express.json()
app.use express.urlencoded()
app.use express.compress()

assets =
	'/assets/scripts.js': [
		'/assets/scripts.js'
	]

app.use(cachify.setup(assets,
	root: __dirname
	url_to_paths: {}
	production: true
))

app.use '/assets', express.static "#{__dirname}/assets"
app.use '/static/bower_components', express.static "#{__dirname}/bower_components"

app.set 'view engine', 'jade'
app.locals.pretty = true
app.set 'views', "#{__dirname}/views"

if newrelic?
	app.locals.newrelic = newrelic


# Hallway middleware

app.use ((request, response) ->
	request.uonline =
		now: new Date()
		pjax: request.header('X-PJAX')?
		sessid: request.cookies.sessid
	# Read session data
	sessionData = lib.user.sessionInfoRefreshing.sync(null,
		dbConnection, request.cookies.sessid, config.sessionExpireTime, true)
	request.uonline.loggedIn = sessionData.sessionIsActive
	request.uonline.username = sessionData.username
	request.uonline.isAdmin = sessionData.admin
	request.uonline.userid = sessionData.userid
	# CSP
	response.header 'Content-Security-Policy', "default-src 'self'; style-src 'self' 'unsafe-inline'"
	# Anti-clickjacking
	response.header 'X-Frame-Options', 'DENY'
	# PJAX
	response.header 'X-PJAX-URL', request.url
	# Necessary, or it will pass shit to callback
	return
).asyncMiddleware()


# Middlewares

mustBeAuthed = (request, response, next) ->
	if request.uonline.loggedIn is true
		next()
	else
		response.redirect '/login/'


mustNotBeAuthed = (request, response, next) ->
	if request.uonline.loggedIn is true
		response.redirect config.defaultInstanceForUsers
	else
		next()


setInstance = (x) ->
	((request, response) ->
		request.uonline.instance = x
		return
	).asyncMiddleware()


render = (template) ->
	(request, response) ->
		response.render template, request.uonline


fetchMonsterFromURL = ((request, response) ->
	chars = lib.game.getMonsterPrototypeCharacters.sync null, dbConnection, request.param 'id'
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return
).asyncMiddleware()


fetchFightMode = ((request, response) ->
	# TODO: merge these two queries
	# TODO: merge everything from uniusers into one SELECT
	request.uonline.fight_mode = lib.game.isInFight.sync null, dbConnection, request.uonline.userid
	request.uonline.autoinvolved_fm = lib.game.isAutoinvolved.sync null, dbConnection, request.uonline.userid
	return
).asyncMiddleware()


fetchArmor = ((request, response) ->
	request.uonline.armor = lib.game.getUserArmor.sync null, dbConnection, request.uonline.userid
	return
).asyncMiddleware()


fetchLocation = ((request, response) ->
	try
		location = lib.game.getUserLocation.sync null, dbConnection, request.uonline.userid
		request.uonline.location_id = location.id
		request.uonline.location_name = location.title
		#request.uonline.pic = request.uonline.picture  if request.uonline.picture?  # TODO: LOLWHAT
		request.uonline.description = location.description
		request.uonline.ways = location.ways
	catch e
		console.error e.stack
		location = lib.game.getInitialLocation.sync null, dbConnection
		lib.game.changeLocation.sync null, dbConnection, request.uonline.userid, location.id
	return
).asyncMiddleware()


fetchArea = ((request, response) ->
	area = lib.game.getUserArea.sync null, dbConnection, request.uonline.userid
	request.uonline.area_name = area.title
	return
).asyncMiddleware()


fetchUsersNearby = ((request, response) ->
	tmpUsers = lib.game.getNearbyUsers.sync null,
		dbConnection, request.uonline.userid, request.uonline.location_id
	request.uonline.players_list = tmpUsers
	return
).asyncMiddleware()


fetchMonstersNearby = ((request, response) ->
	tmpMonsters = lib.game.getNearbyMonsters.sync null, dbConnection, request.uonline.location_id
	request.uonline.monsters_list = tmpMonsters
	return
).asyncMiddleware()


fetchStats = ((request, response) ->
	chars = lib.game.getUserCharacters.sync null, dbConnection, request.uonline.userid
	for i of chars
		request.uonline[i] = chars[i]
	return
).asyncMiddleware()


fetchStatsFromURL = ((request, response) ->
	chars = lib.game.getUserCharacters.sync null, dbConnection, request.param 'username'
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return
).asyncMiddleware()


fetchBattleGroups = ((request, response) ->
	if request.uonline.fight_mode
		request.uonline.participants = lib.game.getBattleParticipants.sync null,
			dbConnection, request.uonline.userid
		request.uonline.our_side = request.uonline.participants.find(
			(p) -> p.kind=='user' && p.id==request.uonline.userid).side
	return
).asyncMiddleware()


# Pages

app.get '/node/', (request, response) ->
	response.send 'Node.js is up and running.'


app.get '/explode/', (request, response) ->
	throw new Error 'Emulated error.'


app.get '/', (request, response) ->
	if request.uonline.loggedIn is true
		response.redirect config.defaultInstanceForUsers
	else
		response.redirect config.defaultInstanceForGuests


app.get '/about/',
	setInstance('about'), render('about')


app.get '/login/',
	mustNotBeAuthed,
	setInstance('login'), render('login')


app.post '/login/',
	mustNotBeAuthed,
	setInstance('login'),
	(request, response) ->
		if lib.user.accessGranted.sync null, dbConnection, request.body.user, request.body.pass
			sessid = lib.user.createSession.sync null, dbConnection, request.body.user
			response.cookie 'sessid', sessid
			response.redirect '/'
		else
			options = request.uonline
			options.error = true
			options.user = request.body.user
			response.render 'login', options


app.get '/register/',
	mustNotBeAuthed,
	setInstance('register'), render('register')


app.post '/register/',
	mustNotBeAuthed,
	setInstance('register'),
	(request, response) ->
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
			options = request.uonline
			options.error = true
			options.invalidLogin = !usernameIsValid
			options.invalidPass = !passwordIsValid
			options.loginIsBusy = userExists
			options.user = request.body.user
			options.pass = request.body.pass
			response.render 'register', options


app.get '/profile/',
	mustBeAuthed,
	fetchStats,
	setInstance('myprofile'), render('profile')


app.get '/profile/:username/',
	fetchStatsFromURL,
	setInstance('profile'), render('profile')


app.get '/monster/:id/',
	fetchMonsterFromURL,
	setInstance('monster'), render('monster')


app.get '/action/logout',
	mustBeAuthed,
	(request, response) ->
		lib.user.closeSession.sync null,
			dbConnection, request.uonline.sessid
		response.redirect '/'


app.get '/game/',
	mustBeAuthed,
	fetchLocation, fetchArea, fetchUsersNearby, fetchMonstersNearby,
	fetchFightMode, fetchStats, fetchBattleGroups,
	setInstance('game'), render('game')


app.get '/inventory/',
	mustBeAuthed,
	fetchFightMode, fetchArmor,
	setInstance('inventory'), render('inventory')


app.get '/action/go/:to',
	mustBeAuthed,
	(request, response) ->
		result = lib.game.changeLocation.sync null, dbConnection, request.uonline.userid, request.param 'to'
		if result.result != 'ok'
			console.error "Location change failed: #{result.reason}"
		response.redirect '/game/'


app.get '/action/attack',
	mustBeAuthed,
	(request, response) ->
		lib.game.goAttack.sync null, dbConnection, request.uonline.userid
		response.redirect '/game/'


app.get '/action/escape',
	mustBeAuthed,
	(request, response) ->
		lib.game.goEscape.sync null, dbConnection, request.uonline.userid
		response.redirect '/game/'


app.get '/action/hit/:kind/:id',
	mustBeAuthed,
	(request, response) ->
		lib.game.hitOpponent.sync(
			null, dbConnection,
			request.uonline.userid,
			request.param('id'), request.param('kind')
		)
		response.redirect '/game/'


app.get '/ajax/isNickBusy/:nick',
	(request, response) ->
		response.json
			nick: request.param('nick')
			isNickBusy: lib.user.userExists.sync null, dbConnection, request.param('nick')


app.get '/ajax/cheatFixAll',
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE armor '+
				'SET strength = '+
				'(SELECT strength_max FROM armor_prototypes '+
				'WHERE armor.prototype = armor_prototypes.id)'+
				'',
			[]
		response.send 'Вроде сработало.'


# 404 handling
app.get '*', (request, response) ->
	throw new Error '404'


# Exception handling
app.use (error, request, response, next) ->
	code = 500
	if error.message is '404'
		code = 404
	else
		console.error error.stack
	options = request.uonline
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
