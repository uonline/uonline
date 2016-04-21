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

async = require 'asyncawait/async'
await = require 'asyncawait/await'
config = require '../config'
math = require '../lib/math.coffee'
sugar = require 'sugar'


# Returns id of location where users must be sent by default
# (after creation, in case of some errors, ...).
exports.getInitialLocation = async (db) ->
	result = await db.queryAsync "SELECT * FROM locations WHERE initial = 1"
	if result.rows.length is 0
		throw new Error 'initial location is not defined'
	if result.rows.length > 1
		throw new Error 'there is more than one initial location'
	return result.rows[0]


# Returns id of character's current location.
exports.getCharacterLocationId = async (db, character_id, callback) ->
	result = await db.queryAsync 'SELECT location FROM characters WHERE id = $1', [character_id]
	if result.rows.length is 0
		throw new Error("wrong character's id")
	return result.rows[0].location


# Returns all attributes of character's current location.
exports.getCharacterLocation = async (db, character_id) ->
	result = await db.queryAsync "SELECT locations.* FROM locations, characters "+
		"WHERE characters.id=$1 AND locations.id = characters.location", [character_id]
	if result.rows.length is 0
		throw new Error "wrong character's id or location"
	return result.rows[0]


# Returns all attributes of character's current area.
exports.getCharacterArea = async (db, character_id) ->
	result = await db.queryAsync "SELECT areas.* FROM areas, locations, characters "+
		"WHERE characters.id=$1 AND locations.id = characters.location AND areas.id = locations.area",
		[ character_id ]
	if result.rows.length is 0
		throw new Error "wrong character's id"
	return result.rows[0]


#exports.getAllowedZones = function(db, sessid, callback) {
#	db.query(
#		'SELECT locations.goto FROM locations, uniusers '+
#		'WHERE uniusers.sessid = ? AND locations.id = uniusers.location AND uniusers.fight_mode = 0',
#		[sessid],
#		function (error, result) {
#			if (!!error) {callback(error, null); return;}
#			var a = result.rows[0].goto.split("|");
#			for (var i=0;i<a.length;i++) {
#				var s = a[i].split("=");
#				a[i] = {to: s[1], name: s[0]};
#			}
#			callback(null, a);
#		}
#	);
#};


# Returns wheter user can go to specified location.
exports.isTherePathForCharacterToLocation = async (db, character_id, locid) ->
	locid = parseInt(locid, 10)
	result = await exports.getCharacterLocation db, character_id

	if result.id is locid
		return false  # already here

	for i in result.ways
		if i.target is locid
			return true
	return false


# Creates battle on location between two groups of characters.
# @param [Transaction] tx already started transaction object
# @param [int] locid id of location
# @param [Array] firstSide array of objects describing participants like
# {
#   id: 1, // character id
#   initiative: 12, // initiative of character
# }
# @param [Array] secondSide same as firstSide
exports._createBattleBetween = (tx, locid, firstSide, secondSide) ->
	newBattleId = await(tx.queryAsync(
		'INSERT INTO battles (location) VALUES ($1) RETURNING id',
		[locid])).rows[0].id

	participants = firstSide
		.map((p) -> p.side = 0; return p)
		.concat(secondSide.map((p) -> p.side = 1; return p))
		.sort((a, b) -> b.initiative - a.initiative)
	await tx.queryAsync(
		'INSERT INTO battle_participants (battle, character_id, index, side) VALUES '+
			participants.map((p, i) -> "(#{newBattleId}, #{p.id}, #{i}, #{p.side})").join(', ')
	)
	return newBattleId


# Stops battle.
# Sets autoinvolved_fm to 0 for all involved characters
# and destroys battle and all participant records.
exports._stopBattle = async (tx, battleId) ->
	await tx.queryAsync 'UPDATE characters SET autoinvolved_fm = FALSE '+
		'WHERE id IN (SELECT id FROM battle_participants WHERE battle = $1)', [battleId]
	await tx.queryAsync 'DELETE FROM battle_participants WHERE battle = $1', [battleId]
	await tx.queryAsync 'DELETE FROM battles WHERE id = $1', [battleId]


# Makes character leave battle.
# If he was last on his battle side, stops battle.
exports._leaveBattle = async (tx, battleId, leaverId) ->
	# removing leaver's battle_participant
	leaver = (await tx.queryAsync(
		'DELETE FROM battle_participants '+
			'WHERE character_id = $1 '+
			'RETURNING index, side',
		[ leaverId ]
	)).rows[0]

	unless leaver?
		throw new Error "can't find participant character_id=#{leaverId} in battle ##{battleId}"

	# shifting other participant's indexes
	await tx.queryAsync(
		'UPDATE battle_participants '+
			'SET index = index - 1 '+
			'WHERE battle = $1 AND index > $2',
		[ battleId, leaver.index ]
	)

	await tx.query 'UPDATE characters SET autoinvolved_fm = FALSE WHERE id = $1', [leaverId]

	teammatesCount = +(await tx.queryAsync(
		"SELECT count(*) FROM battle_participants "+
			"WHERE battle = $1 AND side = $2 ",
			[ battleId, leaver.side ]
	)).rows[0].count

	if teammatesCount is 0
		await exports._stopBattle tx, battleId

	return battleEnded: (teammatesCount is 0)


# Changes character location and starts (maybe) battle with some monsters.
exports.changeLocation = async (db, character_id, locid, throughSpaceAndTime) ->
	battle = await(db.queryAsync(
		"SELECT battle AS id FROM battle_participants WHERE character_id = $1 FOR UPDATE",
		[ character_id ]
	)).rows[0]
	isInFight = battle?

	if throughSpaceAndTime
		if isInFight
			await exports._leaveBattle db, battle.id, character_id
		await db.queryAsync "UPDATE characters SET location = $1 WHERE id = $2", [locid, character_id]
		return {
			result: 'ok'
		}

	canGo = await exports.isTherePathForCharacterToLocation db, character_id, locid
	if isInFight
		return {
			result: 'fail'
			reason: "Character ##{character_id} is in fight"
		}
	unless canGo
		return {
			result: 'fail'
			reason: "No path to location ##{locid} for character ##{character_id}"
		}

	await db.queryAsync 'SELECT id FROM characters WHERE id = $1 FOR UPDATE', [character_id]
	monsters = await(db.queryAsync(
		"SELECT id, initiative, attack_chance "+
			"FROM characters "+
			"WHERE characters.location = $1 "+
			"AND player IS NULL "+
			"AND NOT EXISTS ("+  # not in battle
				"SELECT 1 FROM battle_participants "+
				"WHERE character_id = characters.id) "+
			"FOR UPDATE",
		[ locid ]
	)).rows

	await db.queryAsync 'UPDATE characters SET location = $1 WHERE id = $2', [locid, character_id]

	pouncedMonsters = (if monsters.some((m) -> Math.random() * 100 <= m.attack_chance) then monsters else [])
	if pouncedMonsters.length > 0
		user =
			id: character_id
			initiative: await(db.queryAsync(
					'SELECT initiative FROM characters WHERE id = $1',
					[ character_id ]
				)).rows[0].initiative
		await exports._createBattleBetween db, locid, pouncedMonsters, [user]

	return {
		result: 'ok'
	}


# Starts battle with monsters on current location.
# prevents starting battle with busy monster
# prevents starting second battle
# Returns true on success and false otherwise.
exports.goAttack = async (db, character_id) ->
	user = await(db.queryAsync(
		'SELECT id, initiative, location '+
		'FROM characters '+
		'WHERE id = $1 '+
			"AND ("+  # if not in battle
				"SELECT count(*) FROM battle_participants "+
				"WHERE character_id = $1) = 0 "+
		'FOR UPDATE',
		[ character_id ]
	)).rows[0]

	unless user?
		return false

	monsters = await(db.queryAsync(
		"SELECT id, initiative "+
			"FROM characters "+
			"WHERE location = $1 "+
				"AND player IS NULL "+
				"AND ("+  # if not in battle
					"SELECT count(*) FROM battle_participants "+
					"WHERE character_id = characters.id) = 0 "+
			"FOR UPDATE",
		[user.location]
	)).rows

	if monsters.length is 0
		return false

	await exports._createBattleBetween db, user.location, monsters, [user]
	return true


# Escapes user from battle.
exports.goEscape = async (db, character_id) ->
	battle = await(db.queryAsync(
		"SELECT battle AS id FROM battle_participants WHERE character_id = $1 FOR UPDATE",
		[character_id]
	)).rows[0]
	if battle?
		await exports._leaveBattle db, battle.id, character_id
	return


# Returns user's battle participants as array of objects like
# {
#    character_id: 1, // id of user/monster
#    name: "Vasya", // user's or monster's name
#    index: 3, // turn number, starts from 0
#    side: 0, // side in battle, 0 or 1
#    player: 1 // id of character's player (null for monters)
# }
exports.getBattleParticipants = async (db, character_id) ->
	return await(db.queryAsync(
		"SELECT character_id, index, side, name, player "+
		"FROM battle_participants, characters "+
		"WHERE battle = ("+
				"SELECT battle from battle_participants "+
				"WHERE character_id = $1) "+
			"AND characters.id = battle_participants.character_id "+
		"ORDER BY index",
		[ character_id ]
	)).rows



exports._lockAndGetStatsForBattle = async (tx, character_id) ->
	return await(tx.queryAsync(
		'SELECT battle, side, power '+
			'FROM characters, battles, battle_participants AS bp '+
			'WHERE characters.id = $1 '+
				'AND bp.character_id = $1 '+
				'AND battles.id = bp.battle '+
			'FOR UPDATE',
		[character_id]
	)).rows[0]


exports._hitItem = async (tx, attackerPower, item) ->
	delta = Math.min(attackerPower, item.strength)
	await tx.queryAsync 'UPDATE items SET strength = $1 WHERE id = $2', [
		item.strength - delta
		item.id
	]
	return delta


exports._hitAndGetHealth = async (tx, victimId, hunterPower) ->
	items = await(tx.queryAsync(
		'SELECT items.id, strength, coverage, type '+
			'FROM items, items_proto '+
			'WHERE items.owner = $1 '+
			'AND items.equipped = true '+
			'AND items.prototype = items_proto.id',
		[victimId]
	)).rows

	# damage reduction by shield
	shield = items.find (i) -> i.type == 'shield'
	if shield? and Math.random() * 100 <= shield.coverage
		hunterPower -= await exports._hitItem(tx, hunterPower, shield)

	# damage reduction by armor
	if hunterPower > 0
		armor = items.exclude (i) -> i.type == 'shield'
		percent = 100
		for item in armor
			if Math.random() * percent <= item.coverage
				hunterPower -= await exports._hitItem(tx, hunterPower, item)
				break
			percent -= item.coverage

	# hit itsef
	if hunterPower > 0
		return await(tx.queryAsync(
			'UPDATE characters '+
				'SET health = health - GREATEST(0, $1-defense)/2 * (0.8+RANDOM()*0.4) '+
				'WHERE id = $2 '+
				'RETURNING health',
			[ hunterPower, victimId ]
		)).rows[0].health
	else
		return await(tx.queryAsync(
			'SELECT health FROM characters WHERE id = $1',
			[ victimId ]
		)).rows[0].health


exports._handleDeathInBattle = async (tx, victim_cid, hunter_cid) ->
	victim = await(tx.queryAsync 'SELECT level, player FROM characters WHERE id = $1', [victim_cid]).rows[0]
	hunter = await(tx.queryAsync 'SELECT level, exp, player FROM characters WHERE id = $1', [hunter_cid]).rows[0]
	playerDied = !!victim.player
	killerIsPlayer = !!hunter.player

	if playerDied
		await tx.queryAsync(
			'UPDATE characters '+
				'SET health = health_max, '+
				'    location = (SELECT id FROM locations WHERE initial = 1) '+
				'WHERE id = $1',
			[victim_cid]
		)
	else
		await tx.queryAsync 'DELETE FROM characters WHERE id = $1', [victim_cid]

	if (killerIsPlayer) and (not playerDied)
		hunter.exp += exports.expForKill(hunter.level, victim.level)
		while hunter.exp >= exports.expToLevelup(hunter.level)
			hunter.exp -= exports.expToLevelup(hunter.level)
			hunter.level++
		await tx.queryAsync(
			'UPDATE characters '+
				'SET exp = $2, level = $3 '+
				'WHERE id = $1',
			[hunter_cid, hunter.exp, hunter.level]
		)


exports._hit = (db, hunterId, victimId, withItemId) ->
	cancel = (message) ->
		return {
			state: "cancelled"
			reason: message
		}

	hunter = await exports._lockAndGetStatsForBattle(db, hunterId)
	unless hunter?
		return cancel "hunter not found"

	victim = await exports._lockAndGetStatsForBattle(db, victimId)
	unless victim?
		return cancel "victim not found"

	if withItemId?
		withItem = (await db.queryAsync("SELECT damage, type FROM items, items_proto "+
			"WHERE owner = $1 AND items.id = $2 AND equipped AND items.prototype = items_proto.id",
			[ hunterId, withItemId ])).rows[0]
		unless withItem?
			return cancel "weapon item not found"
		if withItem.damage == 0
			return cancel "can't hit with this item"

	if victim.battle != hunter.battle
		return cancel "different battles"

	if victim.side is hunter.side
		return cancel "can't hit teammate"

	power = hunter.power
	if withItem?
		power += withItem.damage

	health = await exports._hitAndGetHealth(db, victimId, power)
	victimKilled = (health <= 0)
	battleEnded = false
	if victimKilled
		battleEnded = (await exports._leaveBattle db, hunter.battle, victimId).battleEnded
		await exports._handleDeathInBattle db, victimId, hunterId

	return {
		state: "ok"
		victimKilled: victimKilled
		battleEnded: battleEnded
	}


# Deals damage to opponent in user's battle.
exports.hitOpponent = async (db, hunterId, victimId, withItemId) ->
	result = exports._hit(db, hunterId, victimId, withItemId)
	return if result.state isnt "ok" or result.battleEnded

	opponents = (await db.queryAsync(
		"SELECT opponents.character_id "+
			"FROM battle_participants AS opponents, "+
				"(SELECT battle, side FROM battle_participants"+
				" WHERE character_id = $1) AS hunter "+
			"WHERE opponents.battle = hunter.battle "+
			"AND opponents.side != hunter.side",
		[ hunterId ]
	)).rows

	for opponent in opponents
		result = exports._hit(db, opponent.character_id, hunterId)
		return if result.battleEnded



# Returns id and name of users on specified location.
exports.getUsersOnLocation = async (db, locid) ->
	return (await db.queryAsync(
		"SELECT uniusers.id, characters.name FROM uniusers, characters "+
		"WHERE uniusers.sess_time > NOW() - $1 * INTERVAL '1 SECOND' "+
		"AND characters.location = $2 "+
		"AND characters.player = uniusers.id",
		[ config.userOnlineTimeout, locid ]
	)).rows


# Returns all users on locations except one.
exports.getNearbyUsers = async (db, userid, locid) ->
	users = await exports.getUsersOnLocation db, locid
	return users.filter (i) -> i.id != userid


# Select nearby monsters with their characteristics
exports.getNearbyMonsters = async (db, locid) ->
	return (await db.queryAsync(
		"SELECT *, "+
		"  EXISTS(SELECT * FROM battle_participants WHERE character_id = characters.id) AS fight_mode "+
		"FROM characters WHERE location = $1 AND player IS NULL"
		[ locid ]
	)).rows


# Checks if character is in battle.
exports.isInFight = async (db, character_id) ->
	(await db.queryAsync(
		"SELECT count(*) FROM battle_participants WHERE character_id = $1",
		[ character_id ]
	)).rows[0].count > 0


# Checks if character was just involved in battle.
exports.isAutoinvolved = async (db, character_id) ->
	result = await db.queryAsync "SELECT autoinvolved_fm FROM characters WHERE id = $1", [character_id]
	return result.rows[0].autoinvolved_fm


# Clears character's "just envolved" mark.
exports.uninvolve = async (db, character_id) ->
	return await db.queryAsync "UPDATE characters SET autoinvolved_fm = FALSE WHERE id = $1", [character_id]


# Calculates how much experience is required to advance to next level.
exports.expToLevelup = (level) ->
	return math.ap(config.EXP_MAX_START, level, config.EXP_STEP)


# Calculates how much experience gains character for killing someone.
exports.expForKill = (hunter_level, victim_level) ->
	return Math.max(0, 50 + 5 * (victim_level - hunter_level))

# Returns character's attributes.
exports.getCharacter = async (db, character_id_or_name) ->
	field = if typeof(character_id_or_name) == 'number' then 'id' else 'name'
	c = (await db.queryAsync(
		"SELECT *, "+
		"  EXISTS(SELECT * FROM battle_participants WHERE character_id = characters.id) AS fight_mode "+
		"FROM characters WHERE #{field} = $1", [character_id_or_name])).rows[0]

	unless c?
		return null

	c.exp_max = exports.expToLevelup c.level
	return c



# Returns user's characters list with some basic attributes.
exports.getCharacters = async (db, user_id) ->
	return (await db.queryAsync(
		"SELECT id, name, race, gender FROM characters WHERE player = $1 ORDER BY id", [ user_id ])).rows


# Returns character's items.
exports.getCharacterItems = async (db, character_id) ->
	return (await db.queryAsync(
		"SELECT items.id, name, type, class, kind, armor_class, "+
		"       coverage, strength, strength_max, equipped, damage "+
		"FROM items, items_proto "+
		"WHERE items.owner = $1 AND items.prototype = items_proto.id "+
		"ORDER BY items.id",
		[ character_id ]
	)).rows

