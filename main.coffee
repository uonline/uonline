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
	if status >= 200 and status < 300 then color = chalk.green
	if status >= 300 and status < 400 then color = chalk.blue
	if status >= 400 and status < 500 then color = chalk.yellow
	if status >= 500 and status < 600 then color = chalk.red
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
	# Read session data
	user = lib.user.sessionInfoRefreshing.sync(null,
		dbConnection, request.cookies.sessid, config.sessionExpireTime, true)
	request.uonline.user = user
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
	if request.uonline.user.loggedIn is true
		next()
	else
		response.redirect '/login/'


mustNotBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
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


fetchCharacter = ((request, response) ->
	character = lib.game.getCharacter.sync null, dbConnection, request.uonline.user.character_id
	character.location_id = character.location
	request.uonline.character = character
).asyncMiddleware()


fetchMonsterFromURL = ((request, response) ->
	chars = lib.game.getCharacter.sync null, dbConnection, request.param 'id'
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return
).asyncMiddleware()


fetchArmor = ((request, response) ->
	request.uonline.armor = lib.game.getCharacterArmor.sync null, dbConnection, request.uonline.user.character_id
	return
).asyncMiddleware()


fetchLocation = ((request, response) ->
	try
		location = lib.game.getCharacterLocation.sync null, dbConnection, request.uonline.user.character_id
		#request.uonline.pic = request.uonline.picture  if request.uonline.picture?  # TODO: LOLWHAT
	catch e
		console.error e.stack
		location = lib.game.getInitialLocation.sync null, dbConnection
		lib.game.changeLocation.sync null, dbConnection, request.uonline.user.character_id, location.id
	request.uonline.location = location
	return
).asyncMiddleware()


fetchArea = ((request, response) ->
	area = lib.game.getCharacterArea.sync null, dbConnection, request.uonline.user.character_id
	request.uonline.area = area
	return
).asyncMiddleware()


fetchUsersNearby = ((request, response) ->
	tmpUsers = lib.game.getNearbyUsers.sync null,
		dbConnection, request.uonline.user.id, request.uonline.character.location_id
	request.uonline.players_list = tmpUsers
	return
).asyncMiddleware()


fetchMonstersNearby = ((request, response) ->
	tmpMonsters = lib.game.getNearbyMonsters.sync null, dbConnection, request.uonline.character.location_id
	request.uonline.monsters_list = tmpMonsters
	request.uonline.monsters_list.in_fight = tmpMonsters.filter((m) -> m.fight_mode)
	request.uonline.monsters_list.not_in_fight = tmpMonsters.filter((m) -> not m.fight_mode)
	return
).asyncMiddleware()


#fetchStats = ((request, response) ->
#	chars = lib.game.getUserCharacters.sync null, dbConnection, request.uonline.userid
#	for i of chars
#		request.uonline[i] = chars[i]
#	return
#).asyncMiddleware()


fetchStatsFromURL = ((request, response) ->
	chars = lib.game.getUserCharacters.sync null, dbConnection, request.param 'username'
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return
).asyncMiddleware()


fetchBattleGroups = ((request, response) ->
	if request.uonline.character.fight_mode
		participants = lib.game.getBattleParticipants.sync null, dbConnection, request.uonline.user.character_id
		our_side = participants
			.find((p) -> p.character_id is request.uonline.user.character_id)
			.side
		
		request.uonline.battle =
			participants: participants
			our_side: our_side
	return
).asyncMiddleware()


# Pages

app.get '/node/', (request, response) ->
	response.send 'Node.js is up and running.'


app.get '/explode/', (request, response) ->
	throw new Error 'Emulated error.'


app.get '/', (request, response) ->
	if request.uonline.user.loggedIn is true
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
		if lib.user.accessGranted.sync null, dbConnection, request.body.username, request.body.password
			sessid = lib.user.createSession.sync null, dbConnection, request.body.username
			response.cookie 'sessid', sessid
			response.redirect '/'
		else
			options = request.uonline
			options.error = true
			options.user.username = request.body.username
			response.render 'login', options


app.get '/register/',
	mustNotBeAuthed,
	setInstance('register'), render('register')


app.post '/register/',
	mustNotBeAuthed,
	setInstance('register'),
	(request, response) ->
		usernameIsValid = lib.validation.usernameIsValid(request.body.username)
		passwordIsValid = lib.validation.passwordIsValid(request.body.password)
		userExists = lib.user.userExists.sync(null, dbConnection, request.body.username)
		if (usernameIsValid is true) and (passwordIsValid is true) and (userExists is false)
			result = lib.user.registerUser.sync(
				null
				dbConnection
				request.body.username
				request.body.password
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
			options.user.username = request.body.username
			options.user.password = request.body.password
			response.render 'register', options


app.get '/profile/',
	mustBeAuthed,
	fetchCharacter,
	setInstance('myprofile'),
	(request, response) ->
		request.uonline.owner = request.uonline.user
		response.render 'profile', request.uonline


app.get '/profile/:username/',
	setInstance('profile'),
	(request, response) ->
		user = lib.user.getUser.sync null, dbConnection, request.param 'username'
		user.character = lib.game.getCharacter.sync null, dbConnection, user.character_id
		user.isMe = user.id == request.uonline.user.id
		request.uonline.owner = user
		response.render 'profile', request.uonline


app.get '/monster/:id/',
	fetchMonsterFromURL,
	setInstance('monster'), render('monster')


app.get '/action/logout',
	mustBeAuthed,
	(request, response) ->
		lib.user.closeSession.sync null,
			dbConnection, request.uonline.user.sessid
		response.redirect '/'


app.get '/game/',
	mustBeAuthed,
	fetchCharacter, fetchLocation, fetchArea,
	fetchUsersNearby, fetchMonstersNearby,
	fetchBattleGroups,
	setInstance('game'), render('game')


app.get '/inventory/',
	mustBeAuthed, fetchCharacter, fetchArmor,
	setInstance('inventory'), render('inventory')


app.get '/action/go/:to',
	mustBeAuthed,
	(request, response) ->
		result = lib.game.changeLocation.sync null, dbConnection, request.uonline.user.character_id, request.param 'to'
		if result.result != 'ok'
			console.error "Location change failed: #{result.reason}"
		response.redirect '/game/'


app.get '/action/attack',
	mustBeAuthed,
	(request, response) ->
		lib.game.goAttack.sync null, dbConnection, request.uonline.user.character_id
		response.redirect '/game/'


app.get '/action/escape',
	mustBeAuthed,
	(request, response) ->
		lib.game.goEscape.sync null, dbConnection, request.uonline.user.character_id
		response.redirect '/game/'


app.get '/action/hit/:id',
	mustBeAuthed,
	(request, response) ->
		lib.game.hitOpponent.sync(
			null, dbConnection,
			request.uonline.user.character_id,
			request.param('id')
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
		response.redirect '/inventory/'


app.get '/action/unequip/:id',
	mustBeAuthed,
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE armor '+
				'SET equipped = false '+
				'WHERE id = $1 AND owner = $2',
			[request.param('id'), request.uonline.user.character_id]
		response.redirect '/inventory/'


app.get '/action/equip/:id',
	mustBeAuthed,
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE armor '+
				'SET equipped = true '+
				'WHERE id = $1 AND owner = $2',
			[request.param('id'), request.uonline.user.character_id]
		response.redirect '/inventory/'


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
