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
config = require '../config.js'
math = require './math.js'
transaction = require 'any-db-transaction'


# А вот эта штука может пригодиться, ибо что-то мне подсказывает,
# что вылетевший после transaction(dbConnection) эксепшен
# эту транзакцию нифига не отменит...
#
#	function doInTransaction(dbConnection, func)
#	{
#		var tx = transaction(dbConnection);
#		try
#		{
#			func(tx);
#		}
#		catch (e)
#		{
#			if (tx.state() == 'open') tx.rollback();
#			throw e;
#		}
#		if (tx.state() == 'open') tx.commit();
#	}


# Converts location ways from string representation to array.
# For example:
# "Left=1|Middle=2|Right=42"
#   to
# [{target:1, text:"Left"}, {target:2, text:"Middle"}, {target:42, text:"Right"}]
parseLocationWays = (str) ->
	return [] if str is null

	ways = str.split '|'
	for i in [0...ways.length]
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


# Returns id of user's current location.
exports.getUserLocationId = (dbConnection, userid, callback) ->
	dbConnection.query 'SELECT location FROM uniusers WHERE id = $1', [userid], (error, result) ->
		if !!result and result.rows.length is 0
			error = new Error "Wrong user's id"
		callback(error, error || result.rows[0].location)


# Returns all attributes of user's current location.
exports.getUserLocation = ((dbConnection, userid) ->
	result = dbConnection.query.sync(dbConnection, "SELECT locations.* FROM locations, uniusers "+
		"WHERE uniusers.id=$1 AND locations.id = uniusers.location", [userid])
	if result.rows.length is 0
		throw new Error "Wrong user's id or location"
	res = result.rows[0]
	res.ways = parseLocationWays(res.ways)
	return res
).async()


# Returns all attributes of user's current area.
exports.getUserArea = ((dbConnection, userid) ->
	result = dbConnection.query.sync(dbConnection, "SELECT areas.* FROM areas, locations, uniusers "+
		"WHERE uniusers.id=$1 AND locations.id = uniusers.location AND areas.id = locations.area", [userid])
	if result.rows.length is 0
		throw new Error "Wrong user's id"
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
exports.isTherePathForUserToLocation = ((dbConnection, userid, locid) ->
	locid = parseInt(locid, 10)
	result = exports.getUserLocation.sync(null, dbConnection, userid)

	if result.id is locid
		return false  # already here

	for i in result.ways
		if i.target is locid
			return true
	return false
).async()


# Creates battle on location between two groups of creatures.
# @param [Transaction] tx already started transaction object
# @param [int] locid id of location
# @param [Array] firstSide array of objects describing participants like
# {
#   id: 1, // id of user/monster
#   kind: "user", // or "monster"
#   initiative: 12, // initiative of user or monster
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
		'INSERT INTO battle_participants (battle, id, kind, index, side) VALUES '+
			participants.map((p, i) -> "(#{newBattleId}, #{p.id}, '#{p.kind}', #{i}, #{p.side})").join(', ')
	)
	return newBattleId


# Stops battle. Sets autoinvolved_fm to 0 for all involved users,
# destroys battle and all participant records.
exports._stopBattle = (tx, battleId) ->
	tx.query.sync tx, 'UPDATE uniusers SET autoinvolved_fm = 0 '+
		"WHERE id IN (SELECT id FROM battle_participants WHERE battle = $1 AND kind = 'user')", [battleId]
	tx.query.sync tx, 'DELETE FROM battle_participants WHERE battle = $1', [battleId]
	tx.query.sync tx, 'DELETE FROM battles WHERE id = $1', [battleId]


# Makes someone (user or monster) leave battle.
# If he was last on his battle side, stops battle.
# If it is user, sets his autoinvolved_fm to 0.
exports._leaveBattle = (tx, battleId, leaverId, leaverKind) ->
	# removing leaver's battle_participant
	leaver = tx.query.sync(tx,
		'DELETE FROM battle_participants '+
			'WHERE id = $1 AND kind = $2 '+
			'RETURNING index, side',
		[ leaverId, leaverKind ]
	).rows[0]

	unless leaver?
		throw new Error "Can't find participant id=#{leaverId}, kind='#{leaverKind}' in battle ##{battleId}"

	# shifting other participant's indexes
	tx.query.sync(tx,
		'UPDATE battle_participants '+
			'SET index = index - 1 '+
			'WHERE battle = $1 AND index > $2',
		[ battleId, leaver.index ]
	)

	if leaverKind is 'user'
		tx.query.sync(tx,
			'UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1',
			[leaverId]
		)

	teammatesCount = +tx.query.sync(tx,
		"SELECT count(*) FROM battle_participants "+
			"WHERE battle = $1 AND side = $2 ",
			[ battleId, leaver.side ]
	).rows[0].count

	if teammatesCount is 0
		exports._stopBattle tx, battleId

	return (teammatesCount is 0)


# Changes user location and starts (maybe) battle with some monsters.
exports.changeLocation = ((dbConnection, userid, locid, throughSpaceAndTime) ->
	tx = transaction(dbConnection)
	battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE",
		[userid]
	).rows[0]
	isInFight = battle?

	if throughSpaceAndTime
		if isInFight
			exports._leaveBattle tx, battle.id, userid, "user"
		tx.query.sync tx, "UPDATE uniusers SET location = $1 WHERE id = $2", [locid, userid]
		tx.commit()
		return {
			result: 'ok'
		}

	canGo = exports.isTherePathForUserToLocation.sync(null, dbConnection, userid, locid)
	if isInFight
		tx.rollback()
		return {
			result: 'fail'
			reason: "Player ##{userid} is in fight"
		}
	if not canGo
		tx.rollback()
		return {
			result: 'fail'
			reason: "No path to location ##{locid} for user ##{userid}"
		}

	monsters = tx.query.sync(tx,
		"SELECT monsters.id, monsters.initiative, monsters.attack_chance "+
			"FROM uniusers, monsters "+
			"WHERE uniusers.id = $1 " +
			"AND monsters.location = $2 "+
			"AND NOT EXISTS ("+
			"SELECT 1 FROM battle_participants "+
			"WHERE kind = 'monster' AND id = monsters.id) "+
			"FOR UPDATE",
		[ userid, locid ]
	).rows

	pouncedMonsters = (if monsters.some((m) -> Math.random() * 100 <= m.attack_chance) then monsters else [])
	if pouncedMonsters.length > 0
		pouncedMonsters.forEach (m) -> m.kind = 'monster'
		user =
			id: userid
			initiative: tx.query.sync(tx,
					'SELECT initiative FROM uniusers WHERE id = $1',
					[userid]
				).rows[0].initiative
			kind: 'user'
		exports._createBattleBetween tx, locid, pouncedMonsters, [user]

	tx.query.sync(tx,
		'UPDATE uniusers SET location = $1'+
			((if pouncedMonsters.length > 0 then ", autoinvolved_fm = 1" else ""))+
			" WHERE id = $2",
		[locid, userid]
	)
	tx.commit.sync(tx)

	return {
		result: 'ok'
	}
).async()


# Starts battle with monsters on current location.
# prevents starting battle with busy monster
# prevents starting second battle
exports.goAttack = ((dbConnection, userid) ->
	tx = transaction(dbConnection)
	monsters = tx.query.sync(tx,
		"SELECT monsters.id, monsters.initiative "+
			"FROM uniusers, monsters "+
			"WHERE uniusers.id = $1 "+
			"AND monsters.location = uniusers.location "+
			"AND ("+
				"SELECT count(*) FROM battle_participants "+
				"WHERE kind='monster' AND id = monsters.id) = 0 "+
			"AND ("+
				"SELECT count(*) FROM battle_participants "+
				"WHERE kind='user' AND id=$1) = 0 "+
			"FOR UPDATE",
		[userid]
	).rows

	if monsters.length is 0
		tx.rollback.sync tx
		return

	for monster in monsters
		monster.kind = "monster"

	user = tx.query.sync(tx, "SELECT initiative, location FROM uniusers WHERE id = $1", [userid]).rows[0]
	user.id = userid
	user.kind = "user"
	exports._createBattleBetween tx, user.location, monsters, [user]
	tx.commit.sync tx
).async()


# Escapes user from battle.
exports.goEscape = ((dbConnection, userid) ->
	tx = transaction(dbConnection)
	battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE",
		[userid]
	).rows[0]
	if battle?
		exports._leaveBattle tx, battle.id, userid, "user"
	tx.commit.sync(tx)
).async()


# Returns user's battle participants as array of objects like
# {
#    id: 1, // id of user/monster
#    kind: "user", // or "monster"
#    name: "Vasya", // user's username or monster's name
#    index: 3, // turn number, starts from 0
#    side: 0, // side in battle, 0 or 1
# }
exports.getBattleParticipants = ((dbConnection, userid) ->
	participants = dbConnection.query.sync(dbConnection,
		"SELECT id, kind, index, side FROM battle_participants "+
			"WHERE battle = ("+
				"SELECT battle from battle_participants "+
				"WHERE kind = 'user' AND id = $1) "+
			"ORDER BY index",
		[userid]
	).rows

	for p in participants
		switch p.kind
			when "user"
				p.name = dbConnection.query.sync(dbConnection,
					"SELECT username FROM uniusers WHERE id = $1",
					[p.id]
				).rows[0].username
			when "monster"
				p.name = dbConnection.query.sync(dbConnection,
					"SELECT monster_prototypes.name FROM monster_prototypes, monsters "+
						"WHERE monsters.id = $1 AND monster_prototypes.id = monsters.prototype",
					[p.id]
				).rows[0].name
			else
				throw new Error "Wrong participant kind: #{p.kind}"
	participants
).async()


exports._lockAndGetStatsForBattle = (tx, id, kind) ->
	switch kind
		when 'user'
			tx.query.sync(tx,
				'SELECT bp.battle, bp.side, uniusers.power '+
					'FROM uniusers, battles, battle_participants AS bp '+
					'WHERE uniusers.id = $1 '+
					'AND bp.id = $1 '+
					"AND bp.kind = 'user' "+
					'AND battles.id = bp.battle '+
					'FOR UPDATE',
				[id]
			).rows[0]
		when 'monster'
			tx.query.sync(tx,
				'SELECT bp.battle, bp.side, monster_prototypes.power '+
					'FROM monsters, battles, battle_participants AS bp, monster_prototypes '+
					'WHERE monsters.id = $1 '+
					'AND bp.id = $1 '+
					"AND bp.kind = 'monster' "+
					'AND battles.id = bp.battle '+
					'AND monster_prototypes.id = monsters.prototype '+
					'FOR UPDATE',
				[id]
			).rows[0]


exports._hitAndGetHealth = (tx, victimId, victimKind, hunterPower) ->
	armor = undefined
	switch victimKind
		when 'user'
			armor = tx.query.sync(tx,
				'SELECT armor.id, strength, coverage '+
					'FROM armor, armor_prototypes '+
					'WHERE armor.owner = $1 '+
					'AND armor.equipped = true '+
					'AND armor.prototype = armor_prototypes.id',
				[victimId]
			).rows
		when 'monster'
			armor = []

	armor_item = null
	percent = 100
	for item in armor
		if Math.random() * percent <= item.coverage
			delta = Math.min(hunterPower, item.strength)
			tx.query.sync tx, 'UPDATE armor SET strength = $1 WHERE id = $2', [
				item.strength - delta
				item.id
			]
			hunterPower -= delta
			break
		percent -= item.coverage

	switch victimKind
		when "user"
			tx.query.sync(tx,
				'UPDATE uniusers '+
					'SET health = health - GREATEST(0, $1-defense)/2 * (0.8+RANDOM()*0.4) '+
					'WHERE id = $2 '+
					'RETURNING health',
				[ hunterPower, victimId ]
			).rows[0].health
		when 'monster'
			tx.query.sync(tx,
				'UPDATE monsters '+
					'SET health = health - GREATEST(0, $1-protos.defense)/2 * (0.8+RANDOM()*0.4) '+
					'FROM monster_prototypes AS protos '+
					'WHERE monsters.id = $2 '+
					'AND protos.id = monsters.prototype '+
					'RETURNING monsters.health',
				[ hunterPower, victimId ]
			).rows[0].health


exports._handleDeathInBattle = (tx, id, kind) ->
	switch kind
		when "monster"
			tx.query.sync tx, "DELETE FROM monsters WHERE id = $1", [id]
		when "user"
			tx.query.sync(tx,
				"UPDATE uniusers "+
					"SET health = health_max, "+
					"    location = (SELECT id FROM locations WHERE initial = 1) "+
					"WHERE id = $1",
				[id]
			)


exports._hit = (dbConnection, hunterId, hunterKind, victimId, victimKind) ->
	tx = transaction(dbConnection)

	hunter = exports._lockAndGetStatsForBattle(tx, hunterId, hunterKind)
	unless hunter?
		tx.rollback.sync(tx)
		return {
			state: "canceled"
			reason: "hunter not found"
		}

	victim = exports._lockAndGetStatsForBattle(tx, victimId, victimKind)
	unless victim?
		tx.rollback.sync(tx)
		return {
			state: "canceled"
			reason: "victim not found"
		}

	if victim.battle != hunter.battle
		tx.rollback.sync(tx)
		return {
			state: "canceled"
			reason: "different battles"
		}

	if victim.side is hunter.side
		tx.rollback.sync(tx)
		return {
			state: "canceled"
			reason: "can't hit teammate"
		}

	health = exports._hitAndGetHealth(tx, victimId, victimKind, hunter.power)
	victimKilled = (health <= 0)
	battleEnded = false
	if victimKilled
		battleEnded = exports._leaveBattle(tx, hunter.battle, victimId, victimKind)
		exports._handleDeathInBattle tx, victimId, victimKind
	tx.commit.sync(tx)

	return {
		state: "ok"
		victimKilled: victimKilled
		battleEnded: battleEnded
	}


# Deals damage to opponent in user's battle.
# Opponent is determined by his 'id' and 'kind' among all participants of user's battle.
exports.hitOpponent = ((dbConnection, userid, participantId, participantKind) ->
	result = exports._hit(dbConnection, userid, "user", participantId, participantKind)
	return if result.state isnt "ok" or result.battleEnded

	opponents = dbConnection.query.sync(dbConnection,
		"SELECT opponents.id, opponents.kind "+
			"FROM battle_participants AS opponents, "+
				"(SELECT battle, side FROM battle_participants"+
				" WHERE id = $1 AND kind = 'user') AS users "+
			"WHERE opponents.battle = users.battle "+
			"AND opponents.side != users.side",
		[userid]
	).rows

	for opponent in opponents
		result = exports._hit(dbConnection, opponent.id, opponent.kind, userid, "user")
		return if result.battleEnded
).async()


# Returns id and username of users on specified location.
exports.getUsersOnLocation = (dbConnection, locid, callback) ->
	dbConnection.query(
		"SELECT id, username FROM uniusers "+
			"WHERE sess_time > NOW() - $1 * INTERVAL '1 SECOND' AND location = $2",
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


# Select nearby monsters with their characteristics (both from monsters and their prototypes)
exports.getNearbyMonsters = (dbConnection, locid, callback) ->
	dbConnection.query(
		"SELECT monster_prototypes.*, monsters.* "+
			"FROM monster_prototypes, monsters "+
			"WHERE monsters.location = $1 "+
			"AND monster_prototypes.id = monsters.prototype",
		[locid],
		(error, result) ->
			callback(error, error || result.rows)
	)


# Checks if user is in battle.
exports.isInFight = ((dbConnection, userid) ->
	dbConnection.query.sync(dbConnection,
		"SELECT count(*) FROM battle_participants WHERE kind = 'user' AND id = $1",
		[userid]
	).rows[0].count > 0
).async()


# Checks if user was just involved in battle.
exports.isAutoinvolved = (dbConnection, userid, callback) ->
	dbConnection.query "SELECT autoinvolved_fm FROM uniusers WHERE id = $1", [userid], (error, result) ->
		callback error, error or (result.rows[0].autoinvolved_fm is 1)


# Clears user's "just envolved" mark.
exports.uninvolve = (dbConnection, userid, callback) ->
	dbConnection.query "UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1", [userid], callback


userCharacters = [
	"id"
	"username"
	"health"
	"health_max"
	"mana"
	"mana_max"
	"energy"
	"power"
	"defense"
	"agility"
	"accuracy"
	"intelligence"
	"initiative"
	"exp"
	"level"
]
joinedUserCharacters = userCharacters.join(",")

# Returns users's characteristics by id or name.
exports.getUserCharacters = ((dbConnection, userIdOrName) ->
	field = (if typeof userIdOrName is 'number' then 'id' else 'username')
	user = dbConnection.query.sync(dbConnection,
		"SELECT "+
			joinedUserCharacters+
			" FROM uniusers WHERE "+
			field+
			" = $1",
		[userIdOrName]
	).rows[0]
	return null unless user?

	user.health_percent = user.health * 100 / user.health_max
	user.mana_percent = user.mana * 100 / user.mana_max
	expPrevMax = math.ap(config.EXP_MAX_START, user.level - 1, config.EXP_STEP)
	user.exp_max = math.ap(config.EXP_MAX_START, user.level, config.EXP_STEP)
	user.exp_percent = (user.exp - expPrevMax) * 100 / (user.exp_max - expPrevMax)
	return user
).async()


exports.getUserArmor = ((dbConnection, userid) ->
	dbConnection.query.sync(dbConnection,
		"SELECT name, type, coverage, strength, strength_max, equipped "+
			"FROM armor, armor_prototypes "+
			"WHERE armor.owner = $1 AND armor.prototype = armor_prototypes.id",
		[userid]
	).rows
).async()


monsterCharacters = [
	"name"
	"level"
	"power"
	"agility"
	"defense"
	"intelligence"
	"accuracy"
	"initiative_min"
	"health_max"
	"mana_max"
	"energy"
	"initiative_max"
]

exports.getMonsterPrototypeCharacters = ((dbConnection, id) ->
	result = dbConnection.query.sync(dbConnection,
		"SELECT #{monsterCharacters.join(', ')} FROM monster_prototypes WHERE id = $1",
		[id]
	).rows
	return result[0] || null
).async()
