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

sync = require 'sync'
config = require '../config'
math = require '../lib/math.coffee'
transaction = require 'any-db-transaction'
sugar = require 'sugar'



# Converts location ways from string representation to array.
# For example:
# "Left=1|Middle=2|Right=42"
#   to
# [{target:1, text:"Left"}, {target:2, text:"Middle"}, {target:42, text:"Right"}]
parseLocationWays = (str) ->
	return [] if str is null

	ways = str.split '|'
	for i of ways
		s = ways[i].split '='
		ways[i] = {
			target: parseInt(s[1], 10)
			text: s[0]
		}

	return ways


# Returns id of location where users must be sent by default
# (after creation, in case of some errors, ...).
exports.getInitialLocation = ((dbConnection) ->
	result = dbConnection.query.sync(dbConnection, "SELECT * FROM locations WHERE initial = 1")
	if result.rows.length is 0
		throw new Error 'initial location is not defined'
	if result.rows.length > 1
		throw new Error 'there is more than one initial location'
	res = result.rows[0]
	res.ways = parseLocationWays(res.ways)
	return res
).async()


# Returns id of character's current location.
exports.getCharacterLocationId = (dbConnection, character_id, callback) ->
	dbConnection.query 'SELECT location FROM characters WHERE id = $1', [character_id], (error, result) ->
		if !!result and result.rows.length is 0
			error = new Error "Wrong character's id"
		callback(error, error || result.rows[0].location)


# Returns all attributes of character's current location.
exports.getCharacterLocation = ((dbConnection, character_id) ->
	result = dbConnection.query.sync(dbConnection, "SELECT locations.* FROM locations, characters "+
		"WHERE characters.id=$1 AND locations.id = characters.location", [character_id])
	if result.rows.length is 0
		throw new Error "Wrong character's id or location"
	res = result.rows[0]
	res.ways = parseLocationWays(res.ways)
	return res
).async()


# Returns all attributes of character's current area.
exports.getCharacterArea = ((dbConnection, character_id) ->
	result = dbConnection.query.sync(dbConnection, "SELECT areas.* FROM areas, locations, characters "+
		"WHERE characters.id=$1 AND locations.id = characters.location AND areas.id = locations.area",
		[ character_id ])
	if result.rows.length is 0
		throw new Error "Wrong character's id"
	result.rows[0]
).async()


#exports.getAllowedZones = function(dbConnection, sessid, callback) {
#	dbConnection.query(
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
exports.isTherePathForCharacterToLocation = ((dbConnection, character_id, locid) ->
	locid = parseInt(locid, 10)
	result = exports.getCharacterLocation.sync(null, dbConnection, character_id)

	if result.id is locid
		return false  # already here

	for i in result.ways
		if i.target is locid
			return true
	return false
).async()


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
	newBattleId = tx.query.sync(tx,
		'INSERT INTO battles (location) VALUES ($1) RETURNING id', [locid]
	).rows[0].id

	participants = firstSide
		.map((p) -> p.side = 0; return p)
		.concat(secondSide.map((p) -> p.side = 1; return p))
		.sort((a, b) -> b.initiative - a.initiative)
	tx.query.sync(
		tx
		'INSERT INTO battle_participants (battle, character_id, index, side) VALUES '+
			participants.map((p, i) -> "(#{newBattleId}, #{p.id}, #{i}, #{p.side})").join(', ')
	)
	return newBattleId


# Stops battle.
# Sets autoinvolved_fm to 0 for all involved characters
# and destroys battle and all participant records.
exports._stopBattle = (tx, battleId) ->
	tx.query.sync tx, 'UPDATE characters SET autoinvolved_fm = FALSE '+
		'WHERE id IN (SELECT id FROM battle_participants WHERE battle = $1)', [battleId]
	tx.query.sync tx, 'DELETE FROM battle_participants WHERE battle = $1', [battleId]
	tx.query.sync tx, 'DELETE FROM battles WHERE id = $1', [battleId]


# Makes character leave battle.
# If he was last on his battle side, stops battle.
exports._leaveBattle = (tx, battleId, leaverId) ->
	# removing leaver's battle_participant
	leaver = tx.query.sync(tx,
		'DELETE FROM battle_participants '+
			'WHERE character_id = $1 '+
			'RETURNING index, side',
		[ leaverId ]
	).rows[0]

	unless leaver?
		throw new Error "Can't find participant character_id=#{leaverId} in battle ##{battleId}"

	# shifting other participant's indexes
	tx.query.sync(tx,
		'UPDATE battle_participants '+
			'SET index = index - 1 '+
			'WHERE battle = $1 AND index > $2',
		[ battleId, leaver.index ]
	)

	tx.query.sync(tx, 'UPDATE characters SET autoinvolved_fm = FALSE WHERE id = $1', [leaverId])

	teammatesCount = +tx.query.sync(tx,
		"SELECT count(*) FROM battle_participants "+
			"WHERE battle = $1 AND side = $2 ",
			[ battleId, leaver.side ]
	).rows[0].count

	if teammatesCount is 0
		exports._stopBattle tx, battleId

	return battleEnded: (teammatesCount is 0)


# Changes character location and starts (maybe) battle with some monsters.
exports.changeLocation = ((dbConnection, character_id, locid, throughSpaceAndTime) ->
	tx = transaction(dbConnection)
	battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE character_id = $1 FOR UPDATE",
		[ character_id ]
	).rows[0]
	isInFight = battle?

	if throughSpaceAndTime
		if isInFight
			exports._leaveBattle tx, battle.id, character_id
		tx.query.sync tx, "UPDATE characters SET location = $1 WHERE id = $2", [locid, character_id]
		tx.commit()
		return {
			result: 'ok'
		}

	canGo = exports.isTherePathForCharacterToLocation.sync(null, dbConnection, character_id, locid)
	if isInFight
		tx.rollback()
		return {
			result: 'fail'
			reason: "Character ##{character_id} is in fight"
		}
	unless canGo
		tx.rollback()
		return {
			result: 'fail'
			reason: "No path to location ##{locid} for character ##{character_id}"
		}

	tx.query.sync(tx, 'SELECT id FROM characters WHERE id = $1 FOR UPDATE', [character_id])
	monsters = tx.query.sync(tx,
		"SELECT id, initiative, attack_chance "+
			"FROM characters "+
			"WHERE characters.location = $1 "+
			"AND player IS NULL "+
			"AND NOT EXISTS ("+  # not in battle
				"SELECT 1 FROM battle_participants "+
				"WHERE character_id = characters.id) "+
			"FOR UPDATE",
		[ locid ]
	).rows

	tx.query.sync(tx, 'UPDATE characters SET location = $1 WHERE id = $2', [locid, character_id])

	pouncedMonsters = (if monsters.some((m) -> Math.random() * 100 <= m.attack_chance) then monsters else [])
	if pouncedMonsters.length > 0
		user =
			id: character_id
			initiative: tx.query.sync(tx,
					'SELECT initiative FROM characters WHERE id = $1',
					[ character_id ]
				).rows[0].initiative
		exports._createBattleBetween tx, locid, pouncedMonsters, [user]

	tx.commit.sync(tx)

	return {
		result: 'ok'
	}
).async()


# Starts battle with monsters on current location.
# prevents starting battle with busy monster
# prevents starting second battle
exports.goAttack = ((dbConnection, character_id) ->
	tx = transaction(dbConnection)

	user = tx.query.sync(tx,
		'SELECT id, initiative, location '+
		'FROM characters '+
		'WHERE id = $1 '+
			"AND ("+  # if not in battle
				"SELECT count(*) FROM battle_participants "+
				"WHERE character_id = $1) = 0 "+
		'FOR UPDATE',
		[ character_id ]
	).rows[0]

	unless user?
		tx.rollback.sync tx
		return

	monsters = tx.query.sync(tx,
		"SELECT id, initiative "+
			"FROM characters "+
			"WHERE location = $1 "+
				"AND player IS NULL "+
				"AND ("+  # if not in battle
					"SELECT count(*) FROM battle_participants "+
					"WHERE character_id = characters.id) = 0 "+
			"FOR UPDATE",
		[user.location]
	).rows

	if monsters.length is 0
		tx.rollback.sync tx
		return

	exports._createBattleBetween tx, user.location, monsters, [user]
	tx.commit.sync tx
).async()


# Escapes user from battle.
exports.goEscape = ((dbConnection, character_id) ->
	tx = transaction(dbConnection)
	battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE character_id = $1 FOR UPDATE",
		[character_id]
	).rows[0]
	if battle?
		exports._leaveBattle tx, battle.id, character_id, "user"
	tx.commit.sync(tx)
).async()


# Returns user's battle participants as array of objects like
# {
#    character_id: 1, // id of user/monster
#    name: "Vasya", // user's or monster's name
#    index: 3, // turn number, starts from 0
#    side: 0, // side in battle, 0 or 1
#    player: 1 // id of character's player (null for monters)
# }
exports.getBattleParticipants = ((dbConnection, character_id) ->
	return dbConnection.query.sync(dbConnection,
		"SELECT character_id, index, side, name, player "+
		"FROM battle_participants, characters "+
		"WHERE battle = ("+
				"SELECT battle from battle_participants "+
				"WHERE character_id = $1) "+
			"AND characters.id = battle_participants.character_id "+
		"ORDER BY index",
		[ character_id ]
	).rows
).async()


exports._lockAndGetStatsForBattle = (tx, character_id) ->
	return tx.query.sync(tx,
		'SELECT battle, side, power '+
			'FROM characters, battles, battle_participants AS bp '+
			'WHERE characters.id = $1 '+
				'AND bp.character_id = $1 '+
				'AND battles.id = bp.battle '+
			'FOR UPDATE',
		[character_id]
	).rows[0]


exports._hitItem = (tx, attackerPower, item) ->
	delta = Math.min(attackerPower, item.strength)
	tx.query.sync tx, 'UPDATE items SET strength = $1 WHERE id = $2', [
		item.strength - delta
		item.id
	]
	return delta


exports._hitAndGetHealth = (tx, victimId, hunterPower) ->
	items = tx.query.sync(tx,
		'SELECT items.id, strength, coverage, type '+
			'FROM items, items_proto '+
			'WHERE items.owner = $1 '+
			'AND items.equipped = true '+
			'AND items.prototype = items_proto.id',
		[victimId]
	).rows

	shield = items.find (i) -> i.type == 'shield'
	if shield? and Math.random() * 100 <= shield.coverage
		hunterPower -= exports._hitItem(tx, hunterPower, shield)

	if hunterPower > 0
		armor = items.exclude (i) -> i.type == 'shield'
		percent = 100
		for item in armor
			if Math.random() * percent <= item.coverage
				hunterPower -= exports._hitItem(tx, hunterPower, item)
				break
			percent -= item.coverage

	if hunterPower > 0
		tx.query.sync(tx,
			'UPDATE characters '+
				'SET health = health - GREATEST(0, $1-defense)/2 * (0.8+RANDOM()*0.4) '+
				'WHERE id = $2 '+
				'RETURNING health',
			[ hunterPower, victimId ]
		).rows[0].health
	else
		tx.query.sync(tx,
			'SELECT health FROM characters WHERE id = $1',
			[ victimId ]
		).rows[0].health


exports._handleDeathInBattle = (tx, character_id) ->
	isUser = !!tx.query.sync(tx, 'SELECT player FROM characters WHERE id = $1', [character_id]).rows[0].player

	if isUser
		tx.query.sync(tx,
			"UPDATE characters "+
				"SET health = health_max, "+
				"    location = (SELECT id FROM locations WHERE initial = 1) "+
				"WHERE id = $1",
			[character_id]
		)
	else
		tx.query.sync tx, "DELETE FROM characters WHERE id = $1", [character_id]


exports._hit = (dbConnection, hunterId, victimId, withItemId) ->
	tx = transaction(dbConnection)

	cancel = (message) ->
		tx.rollback.sync(tx)
		return {
			state: "cancelled"
			reason: message
		}

	hunter = exports._lockAndGetStatsForBattle(tx, hunterId)
	unless hunter?
		return cancel "hunter not found"

	victim = exports._lockAndGetStatsForBattle(tx, victimId)
	unless victim?
		return cancel "victim not found"

	if withItemId?
		withItem = tx.query.sync(tx, "SELECT damage, type FROM items, items_proto "+
			"WHERE owner = $1 AND items.id = $2 AND equipped AND items.prototype = items_proto.id",
			[ hunterId, withItemId ]).rows[0]
		unless withItem?
			return cancel "weapon item not found"
		if withItem.type isnt 'shield' or withItem.damage == 0
			return cancel "can't hit with this item"

	if victim.battle != hunter.battle
		return cancel "different battles"

	if victim.side is hunter.side
		return cancel "can't hit teammate"

	power = hunter.power
	if withItem? and withItem.type == 'shield'
		power += withItem.damage

	health = exports._hitAndGetHealth(tx, victimId, power)
	victimKilled = (health <= 0)
	battleEnded = false
	if victimKilled
		battleEnded = exports._leaveBattle(tx, hunter.battle, victimId).battleEnded
		exports._handleDeathInBattle tx, victimId
	tx.commit.sync(tx)

	return {
		state: "ok"
		victimKilled: victimKilled
		battleEnded: battleEnded
	}


# Deals damage to opponent in user's battle.
exports.hitOpponent = ((dbConnection, hunterId, victimId, withItemId) ->
	result = exports._hit(dbConnection, hunterId, victimId, withItemId)
	return if result.state isnt "ok" or result.battleEnded

	opponents = dbConnection.query.sync(dbConnection,
		"SELECT opponents.character_id "+
			"FROM battle_participants AS opponents, "+
				"(SELECT battle, side FROM battle_participants"+
				" WHERE character_id = $1) AS hunter "+
			"WHERE opponents.battle = hunter.battle "+
			"AND opponents.side != hunter.side",
		[ hunterId ]
	).rows

	for opponent in opponents
		result = exports._hit(dbConnection, opponent.character_id, hunterId)
		return if result.battleEnded
).async()


# Returns id and name of users on specified location.
exports.getUsersOnLocation = (dbConnection, locid, callback) ->
	dbConnection.query(
		"SELECT uniusers.id, characters.name FROM uniusers, characters "+
		"WHERE uniusers.sess_time > NOW() - $1 * INTERVAL '1 SECOND' "+
		"AND characters.location = $2 "+
		"AND characters.player = uniusers.id",
		[ config.userOnlineTimeout, locid ],
		(error, result) ->
			callback(error, error || result.rows)
	)


# Returns all users on locations except one.
exports.getNearbyUsers = (dbConnection, userid, locid, callback) ->
	exports.getUsersOnLocation dbConnection, locid, (error, result) ->
		callback error, null if error?

		result = result.filter (i) -> i.id != userid
		callback null, result


# Select nearby monsters with their characteristics
exports.getNearbyMonsters = (dbConnection, locid, callback) ->
	dbConnection.query(
		"SELECT *, "+
		"  EXISTS(SELECT * FROM battle_participants WHERE character_id = characters.id) AS fight_mode "+
		"FROM characters WHERE location = $1 AND player IS NULL"
		[ locid ],
		(error, result) ->
			callback(error, error || result.rows)
	)


# Checks if character is in battle.
exports.isInFight = ((dbConnection, character_id) ->
	dbConnection.query.sync(dbConnection,
		"SELECT count(*) FROM battle_participants WHERE character_id = $1",
		[ character_id ]
	).rows[0].count > 0
).async()


# Checks if character was just involved in battle.
exports.isAutoinvolved = (dbConnection, character_id, callback) ->
	dbConnection.query "SELECT autoinvolved_fm FROM characters WHERE id = $1", [character_id], (error, result) ->
		callback error, error or result.rows[0].autoinvolved_fm


# Clears character's "just envolved" mark.
exports.uninvolve = (dbConnection, character_id, callback) ->
	dbConnection.query "UPDATE characters SET autoinvolved_fm = FALSE WHERE id = $1", [character_id], callback


# Returns character's attributes.
exports.getCharacter = ((dbConnection, character_id_or_name) ->
	field = if typeof(character_id_or_name) == 'number' then 'id' else 'name'
	c = dbConnection.query.sync(dbConnection,
		"SELECT *, "+
		"  EXISTS(SELECT * FROM battle_participants WHERE character_id = characters.id) AS fight_mode "+
		"FROM characters WHERE #{field} = $1", [character_id_or_name]).rows[0]

	unless c?
		return null

	c.health_percent = c.health * 100 / c.health_max
	c.mana_percent = c.mana * 100 / c.mana_max
	c.energy_percent = c.energy * 100 / c.energy_max
	expPrevMax = math.ap(config.EXP_MAX_START, c.level - 1, config.EXP_STEP)
	c.exp_max = math.ap(config.EXP_MAX_START, c.level, config.EXP_STEP)
	c.exp_percent = (c.exp - expPrevMax) * 100 / (c.exp_max - expPrevMax)
	return c
).async()


# Returns user's characters list with some basic attributes.
exports.getCharacters = ((dbConnection, user_id) ->
	dbConnection.query.sync(dbConnection,
		"SELECT id, name FROM characters WHERE player = $1 ORDER BY id", [ user_id ]).rows
).async()


# Returns character's items.
exports.getCharacterItems = ((dbConnection, character_id) ->
	dbConnection.query.sync(dbConnection,
		"SELECT items.id, name, type, coverage, strength, strength_max, equipped, damage "+
		"FROM items, items_proto "+
		"WHERE items.owner = $1 AND items.prototype = items_proto.id "+
		"ORDER BY items.id",
		[ character_id ]
	).rows
).async()


process.on 'uncaughtException', (err) -> console.log('Caught exception: ' + err.stack)
