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
plural = (n, f) ->
	n %= 100
	if n>10 and n<20 then return f[2]
	n %= 10
	if n>1 and n<5 then return f[1]
	if n is 1 then return f[0] else return f[2]

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


asyncMiddleware = (func) ->
	return (req, res, next) ->
		func(req, res).then((-> next()), next)


wrap = (func) ->
	return (req, res, next) ->
		func(req, res, next).catch(next)


# Hallway middleware
app.use asyncMiddleware async (request, response) ->
	# Basic stuff
	request.uonline =
		now: new Date()
		pjax: request.header('X-PJAX')?
		moment: moment
		plural: plural
		db: dbConnection

	# Read session data
	user = await lib.user.sessionInfoRefreshing(
		request.uonline.db, request.cookies.sessid, config.sessionExpireTime, true)
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
	character = await lib.game.getCharacter request.uonline.db, request.uonline.user.character_id
	if character?
		writeDisplayRace(character)
	request.uonline.character = character

	# Read all user's characters data
	characters = await lib.game.getCharacters request.uonline.db, request.uonline.user.id
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


# Middlewares

openTransaction = (request, response, next) ->
	request.uonline.db = promisifyAll transaction(request.uonline.db)
	next()

commit = asyncMiddleware async (request, response) ->
	await request.uonline.db.commitAsync()


mustBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		next()
	else
		response.redirect 303, '/login/'


mustNotBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		response.redirect 303, config.defaultInstanceForUsers
	else
		next()


mustHaveCharacter = (request, response, next) ->
	if request.uonline.character
		next()
	else
		response.redirect 303, '/account/'


setInstance = (x) ->
	(request, response, next) ->
		request.uonline.instance = x
		next()


render = (template) ->
	(request, response) ->
		response.render template, request.uonline


redirect = (code, url) ->
	(request, response) ->
		response.redirect(code, url)


fetchCharacter = asyncMiddleware async (request, response) ->
	character = await lib.game.getCharacter request.uonline.db, request.uonline.user.character_id
	request.uonline.character = character


fetchCharacterFromURL = asyncMiddleware async (request, response) ->
	request.uonline.fetched_character = await lib.game.getCharacter request.uonline.db, request.params.name


fetchMonsterFromURL = asyncMiddleware async (request, response) ->
	id = parseInt(request.params.id, 10)
	if isNaN(id)
		throw new Error '404'
	chars = await lib.game.getCharacter request.uonline.db, id
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline.fetched_monster = chars
	return


fetchItems = asyncMiddleware async (request, response) ->
	items = await lib.game.getCharacterItems request.uonline.db, request.uonline.user.character_id
	request.uonline.equipment = items.filter (x) -> x.equipped
	request.uonline.equipment.shield = request.uonline.equipment.find (x) -> x.type == 'shield'
	request.uonline.equipment.right_hand = request.uonline.equipment.find (x) -> x.type.startsWith 'weapon'
	request.uonline.backpack = items.filter (x) -> !x.equipped
	return


fetchLocation = asyncMiddleware async (request, response) ->
	try
		location = await lib.game.getCharacterLocation request.uonline.db, request.uonline.user.character_id
		#request.uonline.pic = request.uonline.picture  if request.uonline.picture?  # TODO: LOLWHAT
	catch e
		console.error e.stack
		location = await lib.game.getInitialLocation request.uonline.db
		await lib.game.changeLocation request.uonline.db, request.uonline.user.character_id, location.id
	request.uonline.location = location
	return


fetchArea = asyncMiddleware async (request, response) ->
	area = await lib.game.getCharacterArea request.uonline.db, request.uonline.user.character_id
	request.uonline.area = area
	return


fetchUsersNearby = asyncMiddleware async (request, response) ->
	tmpUsers = await lib.game.getNearbyUsers request.uonline.db,
		request.uonline.user.id, request.uonline.character.location
	request.uonline.players_list = tmpUsers
	return


fetchMonstersNearby = asyncMiddleware async (request, response) ->
	tmpMonsters = await lib.game.getNearbyMonsters request.uonline.db, request.uonline.character.location
	request.uonline.monsters_list = tmpMonsters
	request.uonline.monsters_list.in_fight = tmpMonsters.filter((m) -> m.fight_mode)
	request.uonline.monsters_list.not_in_fight = tmpMonsters.filter((m) -> not m.fight_mode)
	return


#fetchStats = asyncMiddleware async (request, response) ->
#	chars = await lib.game.getUserCharacters request.uonline.db, request.uonline.userid
#	for i of chars
#		request.uonline[i] = chars[i]
#	return


fetchStatsFromURL = asyncMiddleware async (request, response) ->
	chars = await lib.game.getUserCharacters request.uonline.db, request.params.username
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return


fetchBattleGroups = asyncMiddleware async (request, response) ->
	if request.uonline.character.fight_mode
		participants = await lib.game.getBattleParticipants request.uonline.db, request.uonline.user.character_id
		our_side = participants
			.find((p) -> p.character_id is request.uonline.user.character_id)
			.side

		request.uonline.battle =
			participants: participants
			our_side: our_side
	return


# Pages

app.get '/node/', (request, response) ->
	response.send 'Node.js is up and running.'


app.get '/explode/', (request, response) ->
	throw new Error 'Emulated error.'

app.get '/explode_db/', openTransaction, wrap(async (request, response) ->
	await request.uonline.db.queryAsync 'SELECT * FROM "Emulated DB error."'
), commit


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


app.post '/action/login',
	mustNotBeAuthed,
	setInstance('login'),
	wrap async (request, response) ->
		if await lib.user.accessGranted request.uonline.db, request.body.username, request.body.password
			sessid = await lib.user.createSession request.uonline.db, request.body.username
			response.cookie 'sessid', sessid
			response.redirect 303, '/'
		else
			options = request.uonline
			options.error = true
			options.user.username = request.body.username
			response.render 'login', options


app.get '/register/',
	mustNotBeAuthed,
	setInstance('register'), render('register')


app.post '/action/register',
	mustNotBeAuthed,
	setInstance('register'),
	openTransaction,
	wrap(async (request, response, next) ->
		usernameIsValid = lib.validation.usernameIsValid(request.body.username)
		passwordIsValid = lib.validation.passwordIsValid(request.body.password)
		userExists = await lib.user.userExists request.uonline.db, request.body.username

		if usernameIsValid and passwordIsValid and !userExists
			result = await lib.user.registerUser(
				request.uonline.db
				request.body.username
				request.body.password
				'user'
			)
			request.uonline.userCreated = true
			response.cookie 'sessid', result.sessid
		else
			options = request.uonline
			options.error = true
			options.invalidLogin = !usernameIsValid
			options.invalidPass = !passwordIsValid
			options.loginIsBusy = userExists
			options.user.username = request.body.username
			options.user.password = request.body.password
			request.uonline.options = options
			request.uonline.userCreated = false
		next()
	),
	commit,
	(request, response) ->
		if request.uonline.userCreated
			response.redirect 303, '/'
		else
			response.render 'register', request.uonline.options


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


app.post '/action/logout',
	mustBeAuthed,
	wrap async (request, response) ->
		await lib.user.closeSession request.uonline.db, request.uonline.user.sessid
		response.redirect 303, '/'  # force GET


app.get '/newCharacter/',
	mustBeAuthed,
	setInstance('new_character'),
	(request, response) ->
		response.render 'new_character', request.uonline


app.post '/action/newCharacter',
	mustBeAuthed,
	setInstance('new_character'),
	openTransaction,
	wrap(async (request, response, next) ->
		nameIsValid = lib.validation.characterNameIsValid(request.body.character_name)
		alreadyExists = await lib.character.characterExists request.uonline.db, request.body.character_name

		if nameIsValid and not alreadyExists
			charid = await lib.character.createCharacter(
				request.uonline.db
				request.uonline.user.id
				request.body.character_name
				request.body.character_race
				request.body.character_gender
			)
			request.uonline._characterCreated = true
		else
			options = request.uonline
			options.error = true
			options.invalidName = !nameIsValid
			options.nameIsBusy = alreadyExists
			options.character_name = request.body.character_name
			request.uonline.options = options
			request.uonline._characterCreated = false
		next()
	),
	commit,
	(request, response) ->
		if request.uonline._characterCreated
			response.redirect 303, '/character/'
		else
			response.render 'new_character', request.uonline.options


app.get '/game/',
	mustBeAuthed,
	mustHaveCharacter, fetchLocation, fetchArea,
	fetchUsersNearby, fetchMonstersNearby,
	fetchBattleGroups, fetchItems,
	setInstance('game'), render('game')


app.get '/inventory/',
	mustBeAuthed, mustHaveCharacter, fetchItems,
	setInstance('inventory'), render('inventory')


app.post '/action/go',
	mustBeAuthed,
	openTransaction,
	wrap(async (request, response, next) ->
		result = await lib.game.changeLocation request.uonline.db,
			request.uonline.user.character_id, request.body.to
		if result.result != 'ok'
			console.error "Location change failed: #{result.reason}"
		next()
	),
	commit,
	redirect(303, '/game/')


app.post '/action/attack',
	mustBeAuthed,
	openTransaction,
	wrap(async (request, response, next) ->
		await lib.game.goAttack request.uonline.db, request.uonline.user.character_id
		next()
	),
	commit,
	redirect(303, '/game/')


app.post '/action/escape',
	mustBeAuthed,
	openTransaction,
	wrap(async (request, response, next) ->
		await lib.game.goEscape request.uonline.db, request.uonline.user.character_id
		next()
	),
	commit,
	redirect(303, '/game/')


app.post '/action/hit',
	mustBeAuthed,
	openTransaction,
	wrap(async (request, response, next) ->
		await lib.game.hitOpponent(
			request.uonline.db,
			request.uonline.user.character_id,
			request.body.id,
			request.body.with_item_id
		)
		next()
	),
	commit,
	redirect(303, '/game/')


app.get '/ajax/isNickBusy/:nick',
	wrap async (request, response) ->
		response.json
			nick: request.params.nick
			isNickBusy: await lib.user.userExists request.uonline.db, request.params.nick


app.get '/ajax/isCharacterNameBusy/:name',
	wrap async (request, response) ->
		response.json
			name: request.params.name
			isCharacterNameBusy: await lib.character.characterExists request.uonline.db, request.params.name


app.post '/ajax/cheatFixAll',
	wrap async (request, response) ->
		await request.uonline.db.queryAsync(
			'UPDATE items '+
			'SET strength = '+
				'(SELECT strength_max FROM items_proto'+
				' WHERE items.prototype = items_proto.id)'
		)
		response.redirect 303, '/inventory/'


app.post '/action/unequip',
	mustBeAuthed,
	wrap async (request, response) ->
		await request.uonline.db.queryAsync(
			'UPDATE items '+
			'SET equipped = false '+
			'WHERE id = $1 AND owner = $2',
			[request.body.id, request.uonline.user.character_id]
		)
		response.redirect 303, '/inventory/'


app.post '/action/equip',
	mustBeAuthed,
	wrap async (request, response) ->
		await request.uonline.db.queryAsync(
			'UPDATE items '+
			'SET equipped = true '+
			'WHERE id = $1 AND owner = $2',
			[request.body.id, request.uonline.user.character_id]
		)
		response.redirect 303, '/inventory/'


app.post '/action/switchCharacter',
	mustBeAuthed,
	wrap async (request, response) ->
		await lib.character.switchCharacter request.uonline.db, request.uonline.user.id, request.body.id
		response.redirect 303, 'back'


app.post '/action/deleteCharacter',
	mustBeAuthed,
	wrap async (request, response) ->
		await lib.character.deleteCharacter request.uonline.db, request.uonline.user.id, request.body.id
		response.redirect 303, '/account/'


app.get '/state/',
	wrap(async (request, response, next) ->
		players = await request.uonline.db.queryAsync(
			"SELECT *, (sess_time > NOW() - $1 * INTERVAL '1 SECOND') AS online FROM uniusers",
			[config.sessionExpireTime]
		)
		request.uonline.userstate = players.rows
		next()
	),
	setInstance('state'), render('state')


# Yandex.Money notification handler.
# Just a draft, not complete.
app.post '/yandex', (request, response) ->
	log = (x) ->
		console.log chalk.blue "[billing] #{x}"
	log 'Got signal.'
	data = request.body
	log require('util').inspect data
	if process.env.YANDEX_SECRET?
		# "notification_type&operation_id&amount&currency&datetime&sender&codepro&notification_secret&label"
		challenge = [
			data.notification_type
			data.operation_id
			data.amount
			data.currency
			data.datetime
			data.sender
			data.codepro
			process.env.YANDEX_SECRET
			data.label
		].join '&'
		# verify
		hasher = require('crypto').createHash 'sha1'
		hasher.update challenge
		sha1 = hasher.digest 'hex'
		if sha1 is data.sha1_hash
			log 'Validation passed, processing.'
			log 'Money, money, money.'
		else
			log 'Hash mismatch, aborting.'
	else
		log 'YANDEX_SECRET env is not set, aborting.'
	response.send 'Queued.'


# 404 handling
app.get '*', (request, response) ->
	throw new Error '404'


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
