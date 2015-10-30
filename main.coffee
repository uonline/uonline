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
sync = require 'sync'
sugar = require 'sugar'
moment = require 'moment'
moment.locale 'ru'
plural = (n, f) ->
	n %= 100
	if n>10 and n<20 then return f[2]
	n %= 10
	if n>1 and n<5 then return f[1]
	if n is 1 then return f[0] else return f[2]


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
	name = req.uonline?.user?.username or '-'
	return chalk.gray(name)
app.use morgan ":remote-addr :uu  :coloredStatus :method :url  #{chalk.gray '":user-agent"'}  :response-time ms"

# middlewares
app.use(require('cookie-parser')())
app.use(require('body-parser').urlencoded(extended: false))
app.use(require('compression')())

# Hashing
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
app.use ((request, response) ->
	request.uonline =
		now: new Date()
		pjax: request.header('X-PJAX')?
		moment: moment
		plural: plural
	# Read session data
	user = lib.user.sessionInfoRefreshing.sync(null,
		dbConnection, request.cookies.sessid, config.sessionExpireTime, true)
	request.uonline.user = user
	# utility
	writeDisplayRace = (x) ->
		tmp = {
			'orc-male': 'орк'
			'orc-female': 'женщина-орк'
			'human-male': 'человек'
			'human-female': 'человек'
			'elf-male': 'эльф'
			'elf-female': 'эльфийка'
		}
		key = "#{x.race}-#{x.gender}"
		x.displayRace = tmp[key]
	# Read character data
	character = lib.game.getCharacter.sync null, dbConnection, request.uonline.user.character_id
	if character?
		writeDisplayRace(character)
	request.uonline.character = character
	# Read all user's characters data
	characters = lib.game.getCharacters.sync null, dbConnection, request.uonline.user.id
	if characters?
		characters.forEach writeDisplayRace
	request.uonline.characters = characters
	# CSP
	if !process.env.NOCSP
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


mustHaveCharacter = (request, response, next) ->
	if request.uonline.character
		next()
	else
		response.redirect '/account/'


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
	request.uonline.character = character
).asyncMiddleware()


fetchCharacterFromURL = ((request, response) ->
	request.uonline.fetched_character = lib.game.getCharacter.sync null, dbConnection, request.params.name
).asyncMiddleware()


fetchMonsterFromURL = ((request, response) ->
	id = parseInt(request.params.id, 10)
	if isNaN(id)
		throw new Error '404'
	chars = lib.game.getCharacter.sync null, dbConnection, id
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline.fetched_monster = chars
	return
).asyncMiddleware()


fetchItems = ((request, response) ->
	items = lib.game.getCharacterItems.sync null, dbConnection, request.uonline.user.character_id
	request.uonline.equipment = items.filter (x) -> x.equipped
	request.uonline.equipment.shield = request.uonline.equipment.find (x) -> x.type == 'shield'
	request.uonline.equipment.right_hand = request.uonline.equipment.find (x) -> x.type.startsWith 'weapon'
	request.uonline.backpack = items.filter (x) -> !x.equipped
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
		dbConnection, request.uonline.user.id, request.uonline.character.location
	request.uonline.players_list = tmpUsers
	return
).asyncMiddleware()


fetchMonstersNearby = ((request, response) ->
	tmpMonsters = lib.game.getNearbyMonsters.sync null, dbConnection, request.uonline.character.location
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
	chars = lib.game.getUserCharacters.sync null, dbConnection, request.params.username
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


app.get '/character/',
	mustBeAuthed, mustHaveCharacter,
	setInstance('mycharacter'),
	(request, response) ->
		#request.uonline.fetched_character_owner = request.uonline.user  # пока не вижу смысла его запрашивать
		request.uonline.fetched_character = request.uonline.character
		response.render 'character', request.uonline


app.get '/character/:name/',
	mustBeAuthed,
	fetchCharacterFromURL,
	setInstance('character'),
	(request, response) ->
		#console.log(require('util').inspect(request.uonline, depth: null))
		response.render 'character', request.uonline


app.get '/account/',
	mustBeAuthed,
	setInstance('account'),
	(request, response) ->
		response.render 'account', request.uonline


app.get '/monster/:id/',
	fetchMonsterFromURL,
	setInstance('monster'), render('monster')


app.get '/action/logout',
	mustBeAuthed,
	(request, response) ->
		lib.user.closeSession.sync null,
			dbConnection, request.uonline.user.sessid
		response.redirect '/'


app.get '/newCharacter/',
	mustBeAuthed,
	setInstance('new_character'),
	(request, response) ->
		response.render 'new_character', request.uonline


app.post '/newCharacter/',
	mustBeAuthed,
	setInstance('new_character'),
	(request, response) ->
		nameIsValid = lib.validation.characterNameIsValid(request.body.character_name)
		alreadyExists = lib.character.characterExists.sync(null, dbConnection, request.body.character_name)

		if nameIsValid and not alreadyExists
			charid = lib.character.createCharacter.sync(
				null
				dbConnection
				request.uonline.user.id
				request.body.character_name
				request.body.character_race
				request.body.character_gender
			)
			response.redirect '/character/'
		else
			options = request.uonline
			options.error = true
			options.invalidName = !nameIsValid
			options.nameIsBusy = alreadyExists
			options.character_name = request.body.character_name
			response.render 'new_character', options


app.get '/game/',
	mustBeAuthed,
	mustHaveCharacter, fetchLocation, fetchArea,
	fetchUsersNearby, fetchMonstersNearby,
	fetchBattleGroups, fetchItems,
	setInstance('game'), render('game')


app.get '/inventory/',
	mustBeAuthed, mustHaveCharacter, fetchItems,
	setInstance('inventory'), render('inventory')


app.get '/action/go/:to',
	mustBeAuthed,
	(request, response) ->
		result = lib.game.changeLocation.sync null, dbConnection, request.uonline.user.character_id, request.params.to
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
			request.params.id,
			request.query.with_item_id
		)
		response.redirect '/game/'


app.get '/ajax/isNickBusy/:nick',
	(request, response) ->
		response.json
			nick: request.params.nick
			isNickBusy: lib.user.userExists.sync null, dbConnection, request.params.nick


app.get '/ajax/isCharacterNameBusy/:name',
	(request, response) ->
		response.json
			name: request.params.name
			isCharacterNameBusy: lib.character.characterExists.sync null, dbConnection, request.params.name


app.get '/ajax/cheatFixAll',
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE items '+
				'SET strength = '+
				'(SELECT strength_max FROM items_proto '+
				'WHERE items.prototype = items_proto.id)'+
				'',
			[]
		response.redirect '/inventory/'


app.get '/action/unequip/:id',
	mustBeAuthed,
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE items '+
				'SET equipped = false '+
				'WHERE id = $1 AND owner = $2',
			[request.params.id, request.uonline.user.character_id]
		response.redirect '/inventory/'


app.get '/action/equip/:id',
	mustBeAuthed,
	(request, response) ->
		dbConnection.query.sync dbConnection,
			'UPDATE items '+
				'SET equipped = true '+
				'WHERE id = $1 AND owner = $2',
			[request.params.id, request.uonline.user.character_id]
		response.redirect '/inventory/'


app.get '/action/switchCharacter/:id',
	mustBeAuthed,
	(request, response) ->
		lib.character.switchCharacter.sync null, dbConnection, request.uonline.user.id, request.params.id
		response.redirect 'back'


app.get '/action/deleteCharacter/:id',
	mustBeAuthed,
	(request, response) ->
		lib.character.deleteCharacter.sync null, dbConnection, request.uonline.user.id, request.params.id
		response.redirect '/account/'


app.get '/state/',
	(request, response, next) ->
		players = dbConnection.query.sync dbConnection,
			"SELECT *, (sess_time > NOW() - $1 * INTERVAL '1 SECOND') AS online FROM uniusers",
			[config.sessionExpireTime]
		request.uonline.userstate = players.rows
		next()
	,
	setInstance('state'), render('state')


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
