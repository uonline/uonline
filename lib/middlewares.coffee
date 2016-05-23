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

transaction = require 'any-db-transaction'
{async, await} = require 'asyncawait'
promisifyAll = require('bluebird').promisifyAll
lib = require '../lib.coffee'


asyncMiddleware = (func) ->
	return (req, res, next) ->
		func(req, res).then((-> next()), next)


# Hallway middleware
exports.hallway = asyncMiddleware async (request, response) ->
	# Basic stuff
	request.routeMatched = false
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


exports.wrap = (func) ->
	(req, res, next) ->
		func(req, res).then((-> next()), next)


exports.setInstance = (x) ->
	(request, response, next) ->
		request.uonline.instance = x
		next()


exports.render = (template) ->
	(request, response, next) ->
		response.render template, request.uonline
		next()


exports.redirect = (code, url) ->
	(request, response) ->
		response.redirect(code, url)


exports.openTransaction = (request, response, next) ->
	request.uonline.db = promisifyAll transaction(request.uonline.db)
	next()


exports.commit = asyncMiddleware async (request, response) ->
	await request.uonline.db.commitAsync()


exports.mustNotBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		response.redirect 303, config.defaultInstanceForUsers
	else
		next()


exports.mustBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		next()
	else
		response.redirect 303, '/login/'


exports.mustHaveCharacter = (request, response, next) ->
	if request.uonline.character
		next()
	else
		response.redirect 303, '/account/'


exports.fetchCharacter = asyncMiddleware async (request, response) ->
	character = await lib.game.getCharacter request.uonline.db, request.uonline.user.character_id
	request.uonline.character = character


exports.fetchCharacterFromURL = asyncMiddleware async (request, response) ->
	request.uonline.fetched_character = await lib.game.getCharacter request.uonline.db, request.params.name


exports.fetchMonsterFromURL = asyncMiddleware async (request, response) ->
	id = parseInt(request.params.id, 10)
	if isNaN(id)
		throw new Error '404'
	chars = await lib.game.getCharacter request.uonline.db, id
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline.fetched_monster = chars
	return


exports.fetchItems = asyncMiddleware async (request, response) ->
	items = await lib.game.getCharacterItems request.uonline.db, request.uonline.user.character_id
	request.uonline.equipment = items.filter (x) -> x.equipped
	request.uonline.equipment.shield = request.uonline.equipment.find (x) -> x.type == 'shield'
	request.uonline.equipment.right_hand = request.uonline.equipment.find (x) -> x.type.startsWith 'weapon'
	request.uonline.backpack = items.filter (x) -> !x.equipped
	return


exports.fetchLocation = asyncMiddleware async (request, response) ->
	try
		location = await lib.game.getCharacterLocation request.uonline.db, request.uonline.user.character_id
		#request.uonline.pic = request.uonline.picture  if request.uonline.picture?  # TODO: LOLWHAT
	catch e
		console.error e.stack
		location = await lib.game.getInitialLocation request.uonline.db
		await lib.game.changeLocation request.uonline.db, request.uonline.user.character_id, location.id
	request.uonline.location = location
	return


exports.fetchArea = asyncMiddleware async (request, response) ->
	area = await lib.game.getCharacterArea request.uonline.db, request.uonline.user.character_id
	request.uonline.area = area
	return


exports.fetchUsersNearby = asyncMiddleware async (request, response) ->
	tmpUsers = await lib.game.getNearbyUsers request.uonline.db,
		request.uonline.user.id, request.uonline.character.location
	request.uonline.players_list = tmpUsers
	return


exports.fetchMonstersNearby = asyncMiddleware async (request, response) ->
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


exports.fetchStatsFromURL = asyncMiddleware async (request, response) ->
	chars = await lib.game.getUserCharacters request.uonline.db, request.params.username
	if not chars?
		throw new Error '404'
	for i of chars
		request.uonline[i] = chars[i]
	return


exports.fetchBattleGroups = asyncMiddleware async (request, response) ->
	if request.uonline.character.fight_mode
		participants = await lib.game.getBattleParticipants request.uonline.db, request.uonline.user.character_id
		our_side = participants
			.find((p) -> p.character_id is request.uonline.user.character_id)
			.side

		request.uonline.battle =
			participants: participants
			our_side: our_side
	return
