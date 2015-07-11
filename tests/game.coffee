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

requireCovered = require '../require-covered.coffee'
game = requireCovered __dirname, '../lib/game.coffee'
config = require '../config'
mg = require '../lib/migration'
sync = require 'sync'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
queryUtils = require '../lib/query_utils'
sugar = require 'sugar'
conn = null
query = null


clearTables = ->
	query 'TRUNCATE ' + [].join.call(arguments, ', ')

insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) VALUES (#{values.map (_,i) -> '$'+(i+1)})", values


exports.setUp = (->
	unless conn?
		try
			conn = anyDB.createConnection(config.DATABASE_URL_TEST)
			queryf = conn.query
			conn.query = () ->
				args = (i for i in arguments)
				cb = args[args.length-1]
				if cb instanceof Function
					stack = new Error().stack
					args[args.length-1] = (err,res) ->
						if err instanceof Error
							err.stack = stack
						cb(err, res)
				queryf.apply this, args
			query = queryUtils.getFor conn
			mg.migrate.sync mg, conn
		catch e
			console.error e
).async() # the entrance to the Fieber land

#exports.tearDown = (->).async()


exports.getInitialLocation =
	'good test': (test) ->
		clearTables 'locations'
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

		loc = game.getInitialLocation.sync null, conn
		test.strictEqual loc.id, 2, 'should return id of initial location'
		test.ok loc.ways instanceof Array, 'should return parsed ways from location'
		test.done()

	'bad test': (test) ->
		clearTables 'locations'
		insert 'locations', id: 1
		insert 'locations', id: 2
		insert 'locations', id: 3

		test.throws(
			-> game.getInitialLocation.sync null, conn
			Error
			'should return error if initial location is not defined'
		)
		test.done()

	'ambiguous test': (test) ->
		clearTables 'locations'
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3, initial: 1
		insert 'locations', id: 4

		test.throws(
			-> game.getInitialLocation.sync null, conn
			Error
			'should return error if there is more than one initial location'
		)
		test.done()


exports.getCharacterLocationId =
	testValidData: (test) ->
		clearTables 'characters'
		insert 'characters', id: 1, 'location': 3

		insert 'characters', id: 2, 'location': 1

		id1 = game.getCharacterLocationId.sync(null, conn, 1)
		id2 = game.getCharacterLocationId.sync(null, conn, 2)
		test.strictEqual id1, 3, "should return user's location id"
		test.strictEqual id2, 1, "should return user's location id"
		test.done()

	testWrongCharacterId: (test) ->
		clearTables 'characters'
		test.throws(
			-> game.getCharacterLocationId.sync(null, conn, -1)
			Error
			'should fail on wrong id'
		)
		test.done()


exports.getCharacterLocation =
	setUp: (done) ->
		clearTables 'characters', 'locations'
		insert 'characters', id: 1, location: 3
		done()

	testValidData: (test) ->
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: 'Left=7|Forward=8|Right=9'
		loc = game.getCharacterLocation.sync(null, conn, 1)

		test.strictEqual loc.id, 3, "should return user's location id"
		test.deepEqual loc.ways, [
				{ target: 7, text: 'Left' }
				{ target: 8, text: 'Forward' }
				{ target: 9, text: 'Right' }
			], 'should return ways from location'
		test.done()

	testWrongCharacterId: (test) ->
		test.throws(
			-> game.getCharacterLocation.sync null, conn, -1
			Error
			'should fail on wrong id'
		)
		test.done()

	testWrongLocid: (test) ->
		insert 'locations', id: 1, area: 5

		test.throws(
			-> game.getCharacterLocation.sync null, conn, 1
			Error
			'should fail if user.location is wrong'
		)
		test.done()


exports.getCharacterArea =
	setUp: (done) ->
		clearTables 'characters', 'locations', 'areas'
		insert 'characters', id: 1, location: 3
		done()

	'usual test': (test) ->
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: 'Left=7|Forward=8|Right=9'
		insert 'areas', id: 5, title: 'London'
		area = game.getCharacterArea.sync null, conn, 1

		test.strictEqual area.id, 5, "should return user's area id"
		test.strictEqual area.title, 'London', "should return user's area name"
		test.done()

	'wrong user id': (test) ->
		test.throws(
			-> game.getCharacterArea.sync null, conn, -1
			Error
			'should fail on wrong id'
		)
		test.done()


exports.isTherePathForCharacterToLocation = (test) ->
	clearTables 'characters', 'locations', 'battle_participants'
	insert 'characters', id: 1, location: 1
	insert 'locations', id: 1, ways: 'Left=2'
	insert 'locations', id: 2

	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 2
	test.strictEqual can, true, "should return true if path exists"

	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
	test.strictEqual can, false, "should return false if already on this location"

	game.changeLocation.sync null, conn, 1, 2
	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
	test.strictEqual can, false, "should return false if path doesn't exist"
	test.done()


exports.createBattleBetween = (test) ->
	clearTables 'battles', 'battle_participants'

	tx = transaction conn
	locid = 123

	game._createBattleBetween tx, locid, [
			{id: 1, initiative:  5}
			{id: 2, initiative: 15}
			{id: 5, initiative: 30}
		], [
			{id: 6, initiative: 20}
			{id: 7, initiative: 10}
		]

	battle = query.row 'SELECT id, location, turn_number FROM battles'
	test.strictEqual battle.location, locid, 'should create battle on specified location'
	test.strictEqual battle.turn_number, 0, 'should create battle that is on first turn'

	participants = query.all 'SELECT character_id AS id, index, side FROM battle_participants WHERE battle = $1',
		[battle.id]
	test.deepEqual participants, [
		{id: 5, index: 0, side: 0}
		{id: 6, index: 1, side: 1}
		{id: 2, index: 2, side: 0}
		{id: 7, index: 3, side: 1}
		{id: 1, index: 4, side: 0}
	], 'should involve all users and monsters of both sides in correct order'

	tx.commit.sync tx
	test.done()


exports._stopBattle = (test) ->
	clearTables 'characters', 'battles', 'battle_participants'
	insert 'characters', id: 1, autoinvolved_fm: true
	insert 'battles', id: 1
	insert 'battle_participants', battle: 1, character_id: 1
	insert 'battle_participants', battle: 1, character_id: 2

	tx = transaction conn
	game._stopBattle(tx, 1)
	tx.commit.sync tx

	test.strictEqual +query.val("SELECT count(*) FROM battles"), 0, 'should remove battle'
	test.strictEqual +query.val("SELECT count(*) FROM battle_participants"), 0, 'should remove participants'
	test.strictEqual +query.val("SELECT autoinvolved_fm FROM characters WHERE id=1"), 0, 'should uninvolve user'
	test.done()


exports._leaveBattle = (test) ->
	clearTables 'characters', 'battles', 'battle_participants'
	insert 'characters', id: 1, autoinvolved_fm: 1
	insert 'characters', id: 2, autoinvolved_fm: 1
	insert 'battles', id: 1
	insert 'battle_participants', battle: 1, character_id: 1, side: 0, index: 1
	insert 'battle_participants', battle: 1, character_id: 2, side: 1, index: 0
	insert 'battle_participants', battle: 1, character_id: 3, side: 0, index: 2
	insert 'battle_participants', battle: 1, character_id: 6, side: 1, index: 3
	insert 'battles', id: 2
	insert 'battle_participants', battle: 2, character_id: 4, side: 0, index: 0
	insert 'battle_participants', battle: 2, character_id: 5, side: 1, index: 1


	tx = transaction conn

	res = game._leaveBattle(tx, 1, 1)
	test.strictEqual res.battleEnded, false, "should return false if wasn't ended"

	test.strictEqual query.val("SELECT autoinvolved_fm FROM characters WHERE id=1"), false,
		'should uninvolve user'

	rows = query.all "SELECT character_id AS id, index FROM battle_participants WHERE battle = 1 ORDER by id"
	test.deepEqual rows, [
			{id:2, index:0}
			{id:3, index:1}
			{id:6, index:2}
		], "should update indexes if participant has gone"


	res = game._leaveBattle(tx, 1, 3, 'user')
	test.strictEqual res.battleEnded, true, 'should return true if battle was ended'

	test.strictEqual query.val("SELECT autoinvolved_fm FROM characters WHERE id=2"), false,
		'should uninvolve involved if one side become empty'
	test.strictEqual +query.val("SELECT count(*) FROM battles WHERE id = 1"), 0,
		'should remove battle if one side become empty'
	test.strictEqual +query.val("SELECT count(*) FROM battle_participants WHERE battle = 1"), 0,
		'should remove participants if one side become empty'

	test.strictEqual +query.val("SELECT count(*) FROM battles"), 1,
		'should not affect other battles'
	test.strictEqual +query.val("SELECT count(*) FROM battle_participants"), 2,
		'should not affect other participants'

	test.throws(
		-> game._leaveBattle(tx, 1, 123)
		Error
		'should throw error if unable to find anyone to leave'
	)

	tx.commit.sync tx
	test.done()


exports.changeLocation =
	setUp: (done) ->
		clearTables 'characters', 'locations', 'battles', 'battle_participants', 'monsters'
		insert 'characters', id: 1, location: 1, initiative: 50
		insert 'locations', id: 1, ways: 'Left=2'
		insert 'locations', id: 2
		done()

	'with peaceful monster': (test) ->
		insert 'monsters', id: 1, location: 2, attack_chance: 0
		game.changeLocation.sync null, conn, 1, 2

		locid = game.getCharacterLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacked if monster attack_chance is 0%'
		test.done()

	'with angry monster': (test) ->
		insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		insert 'characters', id: 12, location: 2, attack_chance: 100, initiative: 5
		insert 'characters', id: 13, location: 2, attack_chance: 0,   initiative: 10
		game.changeLocation.sync null, conn, 1, 2

		locid = game.getCharacterLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, true, "user should be attacked if at least one monster's attack chance is 100%"

		participantsCount = +query.val 'SELECT count(*) FROM battle_participants'
		test.strictEqual participantsCount, 4, 'all monsters should have been involved'

		userSide = query.val "SELECT side FROM battle_participants WHERE character_id=1"
		query.all("SELECT side FROM battle_participants WHERE character_id!=1").forEach (m) ->
			test.ok userSide isnt m.side, 'user and monsters should be on different sides'
		test.done()

	'with busy monster': (test) ->
		insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		insert 'battle_participants', character_id: 11
		game.changeLocation.sync null, conn, 1, 2

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacked if monster is in another battle'
		test.done()

	'in fight already': (test) ->
		insert 'battle_participants', character_id: 1

		game.changeLocation.sync null, conn, 1, 2
		locid = game.getCharacterLocationId.sync null, conn, 1
		test.strictEqual locid, 1, 'should not change location if user is in fight'

		game.changeLocation.sync null, conn, 1, 2, true
		locid = game.getCharacterLocationId.sync null, conn, 1
		test.strictEqual game.isInFight.sync(null, conn, 1), false, 'should remove user from fight...'
		test.strictEqual locid, 2, '...and change location if force flag is set'
		test.done()

	'no way to location': (test) ->
		insert 'locations', id: 3

		game.changeLocation.sync null, conn, 1, 3
		locid = game.getCharacterLocationId.sync null, conn, 1
		test.strictEqual locid, 1, 'should not change location if there is no such way'

		game.changeLocation.sync null, conn, 1, 3, true
		locid = game.getCharacterLocationId.sync null, conn, 1
		test.strictEqual locid, 3, 'should change location despite all roads if force flag is set'
		test.done()


exports.goAttack =
	setUp: (done) ->
		clearTables 'characters', 'battles', 'battle_participants'
		insert 'characters', id: 1, location: 1, initiative: 10, player: 1
		done()

	'usual test': (test) ->
		insert 'characters', id: 11, location: 1, initiative: 20
		insert 'characters', id: 12, location: 1, initiative: 30
		game.goAttack.sync null, conn, 1

		envolvedMonstersCount = +query.val "SELECT count(*) FROM battle_participants WHERE character_id!=1"
		test.strictEqual envolvedMonstersCount, 2, 'all monsters should have been envolved'

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, true, 'user should be attacking'

		envolvedCountBefore = +query.val "SELECT count(*) FROM battle_participants"
		game.goAttack.sync null, conn, 1

		battlesCount = +query.val "SELECT count(*) FROM battles"
		test.strictEqual battlesCount, 1, 'second battle should not be created if user already in battle'

		envolvedCountAfter = +query.val "SELECT count(*) FROM battle_participants"
		test.strictEqual envolvedCountBefore, envolvedCountAfter,
			'no more participants should appear if user already in battle'
		test.done()

	'when one monster is busy': (test) ->
		insert 'characters', id: 11, location: 1, initiative: 20
		insert 'characters', id: 12, location: 1, initiative: 30
		insert 'battle_participants', character_id: 12
		game.goAttack.sync null, conn, 1

		count = +query.val "SELECT count(*) FROM battle_participants WHERE character_id=12"
		test.strictEqual count, 1, 'should not envolve monster in second battle'
		test.done()

	'on empty location': (test) ->
		game.goAttack.sync null, conn, 1

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be fighting'

		test.strictEqual +query.val('SELECT count(*) FROM battles'), 0, 'should be no battles'
		test.strictEqual +query.val('SELECT count(*) FROM battle_participants'), 0, 'should be no participants'
		test.done()


exports.goEscape =
	setUp: (done) ->
		clearTables 'characters', 'battles', 'battle_participants'
		insert 'characters', id: 1, autoinvolved_fm: 1
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 1
		insert 'battle_participants', battle: 3, character_id: 1
		done()

	test: (test) ->
		game.goEscape.sync null, conn, 1

		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacking'

		autoinvolved = query.val 'SELECT autoinvolved_fm FROM characters WHERE id=1'
		test.strictEqual autoinvolved, false, 'user should not be autoinvolved'
		test.done()


exports.getBattleParticipants =
	setUp: (done) ->
		clearTables 'characters', 'battle_participants'
		insert 'characters', id: 1,  name: 'SomeUser', player: 2
		insert 'characters', id: 11, name: 'SomeMonster 1'
		insert 'characters', id: 12, name: 'SomeMonster 2'
		insert 'battle_participants', battle: 3, character_id: 1,  side: 1, index: 1
		insert 'battle_participants', battle: 3, character_id: 11, side: 0, index: 0
		insert 'battle_participants', battle: 3, character_id: 12, side: 0, index: 2
		done()

	test: (test) ->
		participants = game.getBattleParticipants.sync(null, conn, 1)
		test.deepEqual participants, [
			{ character_id: 11, name: 'SomeMonster 1', side: 0, index: 0, player: null }
			{ character_id: 1,  name: 'SomeUser',      side: 1, index: 1, player: 2    }
			{ character_id: 12, name: 'SomeMonster 2', side: 0, index: 2, player: null }
		], 'should return participants with names'
		test.done()


exports._lockAndGetStatsForBattle = (test) ->
	clearTables 'characters', 'battles', 'battle_participants'
	insert 'characters', id: 1,  power: 100
	insert 'characters', id: 11, power: 200
	insert 'battles', id: 3
	insert 'battle_participants', battle: 3, character_id: 1,  side: 1
	insert 'battle_participants', battle: 3, character_id: 11, side: 2

	#select t.relname,mode,granted from pg_locks l, pg_stat_all_tables t where l.relation=t.relid;

	tx = transaction(conn)
	user = game._lockAndGetStatsForBattle(tx, 1)
	test.deepEqual user, {side: 1, power: 100, battle: 3}, 'should return nesessary data'
	tx.rollback.sync(tx)

	tx = transaction(conn)
	user = game._lockAndGetStatsForBattle(tx, 11)
	test.deepEqual user, {side: 2, power: 200, battle: 3}, 'should return nesessary data'
	tx.rollback.sync(tx)
	test.done()


exports._hitItem = (test) ->
	clearTables 'items'
	insert 'items', id: 1, strength: 100

	item = query.row 'SELECT id, strength FROM items'
	power = 80

	queryUtils.doInTransaction conn, (tx) ->
		delta = game._hitItem(tx, power, item)
		item = query.row 'SELECT id, strength FROM items'
		test.strictEqual delta, 80, "should reduce all attacker's power if item is strong"
		test.strictEqual item.strength, 20, "should reduce item's strength"
		
		delta = game._hitItem(tx, power, item)
		item = query.row 'SELECT id, strength FROM items'
		test.strictEqual delta, 20, "should reduce part of attacker's power if item was broken"
		test.strictEqual item.strength, 0, "should reduce item's strength"
	test.done()


exports._hitAndGetHealth =
	setUp: (done) ->
		clearTables 'characters', 'items', 'items_proto'
		insert 'characters', id: 1,  health: 1000, defense: 50
		insert 'characters', id: 11, health: 1000, defense: 50
		done()

	simple: (test) ->
		power = 70
		minDmg = (power - 50) / 2 * 0.8
		maxDmg = (power - 50) / 2 * 1.2
		victim_id = 1

		tx = transaction(conn)

		damages = {}
		prevHP = 1000

		for i in [0..100]
			hp = game._hitAndGetHealth tx, victim_id, power
			hpActual = query.val "SELECT health FROM characters WHERE id=$1", [victim_id]
			test.strictEqual hp, hpActual, "should return current characters's health"

			dmg = prevHP - hp
			test.ok minDmg <= dmg <= maxDmg, "dealed damage should be in fixed range"

			damages[dmg] = true
			prevHP = hp

		test.ok Object.keys(damages).length > 1, "should deal different amounts of damage"
		test.ok damages[minDmg], 'should sometimes deal minimal damage'
		test.ok damages[maxDmg], 'should sometimes deal maximal damage'

		query "UPDATE characters SET defense = 9001"

		hpBefore = prevHP
		hpAfter = game._hitAndGetHealth tx, victim_id, power
		test.strictEqual hpBefore, hpAfter,
			"should not change health if defense is greater than damage"

		tx.rollback.sync(tx)
		test.done()

	'with armor': (test) ->
		power = 70
		damages = null

		userHP = -> query.val 'SELECT health FROM characters WHERE id=1'
		totalStringth = -> query.val 'SELECT SUM(strength) FROM items'

		performSomeAttacks = ->
			damages = {}
			tx = transaction(conn)
			for i in [0..20]
				prevHP = userHP()
				prevSt = totalStringth()

				hp = game._hitAndGetHealth tx, 1, power
				dmg = prevHP - hp
				damages[dmg] = true

				if dmg is 0
					test.ok prevSt > totalStringth(), 'should reduce armor strength if damage was blocked'
			tx.rollback.sync(tx)


		insert 'items_proto', id:1, name: 'breastplate', coverage:25
		insert 'items_proto', id:2, name: 'greave', coverage:25
		insert 'items', prototype:1, owner:1, strength:10000, equipped: true
		insert 'items', prototype:2, owner:1, strength:10000, equipped: true

		performSomeAttacks()
		test.ok damages[0], 'armor should block some attacks if coverage > 0'
		test.ok Object.keys(damages).length > 1, 'armor should not block all attacks if total coverage < 100'

		query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
		performSomeAttacks()
		test.deepEqual damages, {'0': true}, 'armor should block all if total coverage is 100'

		query 'UPDATE items_proto SET coverage = 0'
		performSomeAttacks()
		test.ok 0 not of damages, 'armor should not block anything if total coverage is 0'

		query 'UPDATE items_proto SET coverage = 50'
		query 'UPDATE items SET strength = 0'
		performSomeAttacks()
		test.ok 0 not of damages, 'armor should not block anything if it is broken'

		query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
		query 'UPDATE items SET strength = 10000'
		query 'UPDATE items SET equipped = false'
		performSomeAttacks()
		test.ok 0 not of damages, 'armor should not block anything if it is unequipped'

		test.done()

	'with shield': (test) ->
		insert 'items_proto', id:1, name: 'The Shield', coverage:100, type: 'shield'
		insert 'items_proto', id:2, name: 'greave', coverage:100
		insert 'items', id:10, prototype:1, owner:1, strength:100, equipped: true
		insert 'items', id:20, prototype:2, owner:1, strength:100, equipped: true

		power = 120
		shield = -> query.row('SELECT strength FROM items WHERE id=10')
		greave = -> query.row('SELECT strength FROM items WHERE id=20')

		# shield with 100% coverage
		for i in [0...5]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			test.strictEqual hp, 1000, 'both shield and armor should block damage'
			test.strictEqual shield().strength, 0, 'shield should block damage first'
			test.strictEqual greave().strength, 80, 'armor should block damage not blocked by shield'
			tx.rollback.sync(tx)

		# shield with 50% coverage
		query 'UPDATE items_proto SET coverage = 50'
		query 'UPDATE items SET strength = 1000'
		hits = shield:0, notShield:0
		for i in [0...40]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			if shield().strength < 1000 then hits.shield++
			if greave().strength < 1000 then hits.notShield++
			if hp < 1000 then hits.notShield++
			tx.rollback.sync(tx)
		test.ok hits.shield > 0 and hits.notShield > 0,
			"shield should block some hits if it's coverage is not 100%"
		test.strictEqual hits.shield+hits.notShield, 40, 'all attacks should hit something'

		# shield with 0% coverage
		query 'UPDATE items_proto SET coverage = 0 WHERE id = 1'
		for i in [0...40]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			test.strictEqual shield().strength, 1000, "shield should not block anything if it's coverage is 0%"
			tx.rollback.sync(tx)

		# shield is not equipped
		query 'UPDATE items_proto SET coverage = 100'
		query 'UPDATE items SET equipped = false WHERE id = 10'
		query 'UPDATE items SET strength = 100'
		for i in [0...5]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			test.strictEqual shield().strength, 100, 'shield should receive no damage if not equipped'
			test.strictEqual greave().strength, 0, 'armor should receive all damage if shield is not equipped'
			tx.rollback.sync(tx)

		test.done()


exports._handleDeathInBattle = (test) ->
	clearTables 'characters', 'locations'
	insert 'locations', id: 5, initial: 1
	insert 'characters', id: 1, health: 0, health_max: 1000, player: 1

	tx = transaction(conn)

	game._handleDeathInBattle tx, 1
	test.strictEqual query.val('SELECT location from characters'), 5, 'should return user back to initial location'
	test.strictEqual query.val('SELECT health from characters'), 1000, "should restore user's health"

	clearTables 'characters'
	insert 'characters', id: 11, player: null

	game._handleDeathInBattle tx, 11
	test.strictEqual +query.val('SELECT count(*) FROM characters'), 0, 'should remove monster'

	tx.rollback.sync(tx)
	test.done()


exports._hit =
	setUp: (done) ->
		clearTables 'characters', 'battles', 'battle_participants', 'items', 'items_proto'

		insert 'characters', id: 1, name: 'SomeUser',    defense: 1, power: 40, health: 5
		insert 'characters', id: 2, name: 'AnotherUser', defense: 1, power: 50, health: 1000
		insert 'characters', id: 5, name: 'SomeMonster', defense: 5, power: 20, health: 500
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 5, side: 1, index: 1
		insert 'battle_participants', battle: 3, character_id: 1, side: 0, index: 0
		insert 'battle_participants', battle: 3, character_id: 2, side: 0, index: 2

		insert 'characters', id: 3, name: 'FarAwayUser', power: 10, health: 1000
		insert 'characters', id: 4, name: 'FarAwayMonster', health: 500
		insert 'battles', id: 8
		insert 'battle_participants', battle: 8, character_id: 4, side: 1, index: 1
		insert 'battle_participants', battle: 8, character_id: 3, side: 0, index: 0

		done()

	'hitting without equipment': (test) ->
		# wrong battle
		result = game._hit conn, 1, 4
		hp = query.val 'SELECT health FROM characters WHERE id = 4'
		test.strictEqual hp, 500, 'should not do anything if victim is in another battle'
		test.deepEqual result,
				state: 'cancelled'
				reason: 'different battles'
			'should describe premature termination reason'

		# try hit teammate
		result = game._hit conn, 1, 2
		hp = query.val 'SELECT health FROM characters WHERE id = 2'
		test.strictEqual hp, 1000, 'should not hit teammate'
		test.deepEqual result,
				state: 'cancelled'
				reason: "can't hit teammate"
			'should describe premature termination reason'

		# wrong hunter
		result = game._hit conn, 15, 2
		hp = query.val 'SELECT health FROM characters WHERE id = 2'
		test.strictEqual hp, 1000, 'should not do anything if hunter does not exist'
		test.deepEqual result,
				state: 'cancelled'
				reason: 'hunter not found'
			'should describe premature termination reason'

		# wrong victim
		result = game._hit conn, 5, 12
		test.deepEqual result,
				state: 'cancelled'
				reason: 'victim not found'
			'should describe premature termination reason'


		# simple DD
		result = game._hit conn, 1, 5
		hp = query.val 'SELECT health FROM characters WHERE id = 5'
		test.ok hp < 500, 'should deal damage to victim'
		test.deepEqual result,
				state: 'ok'
				victimKilled: false
				battleEnded: false
			'should describe what had happened'

		# knockout one of opponents
		result = game._hit conn, 5, 1
		rows = query.all "SELECT * FROM battle_participants WHERE character_id = 1"
		test.strictEqual rows.length, 0, 'should remove participant if one was killed'
		test.deepEqual result,
				state: 'ok'
				victimKilled: true
				battleEnded: false
			'should describe what had happened'

		# defeated all opponents
		query 'UPDATE characters SET health = 5 WHERE id = 5'
		result = game._hit conn, 2, 5
		battles = query.all 'SELECT * FROM battles WHERE id = 3'
		participants = query.all 'SELECT * FROM battle_participants WHERE battle = 3'
		test.strictEqual battles.length, 0, 'should stop battle if one side won'
		test.strictEqual participants.length, 0, 'should also remove battle participants'
		test.deepEqual result,
				state: 'ok'
				victimKilled: true
				battleEnded: true
			'should describe what had happened'
		
		test.done()


	'shields': (test) ->
		insert 'items_proto', id:1, name: 'The Shield', coverage:100, type: 'shield', damage: 100
		insert 'items', id:10, prototype:1, owner:1, strength:100, equipped:true

		# hit with normal shield
		result = game._hit conn, 1, 5, 10
		test.strictEqual result.state, 'ok', 'should hit successfully'
		hp = query.val 'SELECT health FROM characters WHERE id = 5'
		test.ok hp < 500-40, 'should deal more damage than barehanded player can'

		# try hit with 0-damage shield
		query "UPDATE items_proto SET damage = 0"
		result = game._hit conn, 1, 5, 10
		test.deepEqual result,
				state: 'cancelled'
				reason: "can't hit with this item"
			'should cancel hit and describe reason if shield has no dmage gain'

		# try hit with non-shield
		query "UPDATE items_proto SET damage = 10, type = 'not-shield'"
		result = game._hit conn, 1, 5, 10
		test.deepEqual result,
				state: 'cancelled'
				reason: "can't hit with this item"
			'should cancel hit and describe reason if it is not shield'

		# try hit with wrong item
		result = game._hit conn, 1, 5, 123
		test.deepEqual result,
				state: 'cancelled'
				reason: 'weapon item not found'
			'should cancel hit and describe reason if item id is wrong'

		test.done()


exports.hitOpponent =
	setUp: (done) ->
		clearTables 'characters', 'battles', 'battle_participants', 'items', 'items_proto', 'monsters'
		insert 'characters', id: 1, name: 'SomeUser', power: 20, defense: 10, health: 1000, player: 1
		insert 'characters', id: 4, name: 'SomeMonster 1', power: 20, defense: 10, health: 1000
		insert 'characters', id: 5, name: 'SomeMonster 2', power: 20, defense: 10, health: 1000
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 4, side: 1, index: 1
		insert 'battle_participants', battle: 3, character_id: 5, side: 1, index: 2
		insert 'battle_participants', battle: 3, character_id: 1, side: 0, index: 0
		done()

	'normal attack': (test) ->
		minDmg = (20-10)/2 * 0.8

		game.hitOpponent conn, 1, 4
		hp = query.val 'SELECT health FROM characters WHERE id = 4'
		test.ok hp <= 1000-minDmg, 'should hit'
		hp = query.val 'SELECT health FROM characters WHERE id = 1'
		test.ok hp <= 1000-minDmg*2, 'victims should hit back'

		query 'UPDATE characters SET health=1 WHERE id = 4'
		query 'UPDATE characters SET health=1000 WHERE id = 1'
		game.hitOpponent conn, 1, 4
		hp = query.val 'SELECT health FROM characters WHERE id = 1'
		test.ok hp <= 1000-minDmg, 'only alive opponents should hit back'
		test.done()

	'defeating target': (test) ->
		query "DELETE FROM battle_participants WHERE character_id = 5"
		query 'UPDATE characters SET health=1 WHERE id=4'

		game.hitOpponent conn, 1, 4
		count = +query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle defeating last opponent'
		test.done()

	'defeated by target': (test) ->
		query 'UPDATE characters SET health = 1'
		game.hitOpponent conn, 1, 4
		count = +query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle when defeated by opponent'
		test.done()


exports.getNearbyUsers =
	setUp: (done) ->
		d = new Date()
		now = (d.getFullYear() + 1) + '-' + (d.getMonth() + 1) + '-' + d.getDate()
		clearTables 'characters', 'uniusers', 'locations'
		insert 'uniusers', id: 1, sess_time: now
		insert 'uniusers', id: 2, sess_time: now
		insert 'uniusers', id: 3, sess_time: now
		insert 'uniusers', id: 4, sess_time: '1980-01-01'
		insert 'uniusers', id: 5, sess_time: now
		insert 'characters', id: 1, name: 'someuser',  location: 1, player: 1
		insert 'characters', id: 2, name: 'otheruser', location: 1, player: 2
		insert 'characters', id: 3, name: 'thirduser', location: 1, player: 3
		insert 'characters', id: 4, name: 'AFKuser',   location: 1, player: 4
		insert 'characters', id: 5, name: 'aloneuser', location: 2, player: 5
		insert 'locations', id: 1
		done()

	testValidData: (test) ->
		users = game.getNearbyUsers.sync null, conn, 1, 1
		test.deepEqual users, [
			{ id: 2, name: 'otheruser' }
			{ id: 3, name: 'thirduser' }
		], 'should return all online users on this location'

		users = game.getNearbyUsers.sync null, conn, 5, 2
		test.deepEqual users, [], 'alone user should be alone. for now'
		test.done()


exports.getNearbyMonsters = (test) ->
	clearTables 'characters'
	insert 'characters', id: 1, location: 1, player: 1
	insert 'characters', id: 2, location: 2, player: 2
	insert 'characters', id: 11, location: 1, attack_chance: 42, name: 'The Creature of Unimaginable Horror'
	insert 'characters', id: 12, location: 2
	insert 'characters', id: 13, location: 2
	monsters = game.getNearbyMonsters.sync null, conn, 1

	test.strictEqual monsters.length, 1, 'should not return excess monsters'
	test.strictEqual monsters[0].attack_chance, 42, "should return monster's info"
	test.strictEqual monsters[0].name, 'The Creature of Unimaginable Horror', 'should return prototype info too'
	test.done()


exports.isInFight = (test) ->
	clearTables 'characters', 'battle_participants'
	insert 'characters', id: 2
	insert 'characters', id: 4
	insert 'battle_participants', character_id: 4

	isIn = game.isInFight.sync null, conn, 2
	test.strictEqual isIn, false, 'should return false if user is not in fight mode'

	isIn = game.isInFight.sync null, conn, 4
	test.strictEqual isIn, true, 'should return true if user is in fight mode'
	test.done()


exports.isAutoinvolved = (test) ->
	clearTables 'characters'
	insert 'characters', id: 2, autoinvolved_fm: false
	insert 'characters', id: 4, autoinvolved_fm: true

	autoinv = game.isAutoinvolved.sync null, conn, 2
	test.strictEqual autoinv, false, 'should return false if user was not attacked'

	autoinv = game.isAutoinvolved.sync null, conn, 4
	test.strictEqual autoinv, true, 'should return true if user was attacked'
	test.done()

exports.uninvolve = (test) ->
	clearTables 'characters', 'battle_participants'
	insert 'characters', id: 1, autoinvolved_fm: true
	insert 'battle_participants', character_id: 1
	game.uninvolve.sync null, conn, 1

	isInFight = game.isInFight.sync null, conn, 1
	test.strictEqual isInFight, true, 'should not disable fight mode'

	autoinvolved = query.val 'SELECT autoinvolved_fm FROM characters WHERE id=1'
	test.strictEqual autoinvolved, false, 'user should not be autoinvolved'
	test.done()


exports.getCharacter =
	testNoErrors: (test) ->
		data =
			id: 1
			name: 'someuser'
			autoinvolved_fm: true
			health: 100
			health_max: 200
			mana: 50
			mana_max: 200
			exp: 1000
			level: 2
			energy: 128
			energy_max: 256
			power: 1
			defense: 2
			agility: 3
			accuracy: 4
			intelligence: 5
			initiative: 6
			attack_chance: 32
			player: 1
			location: 2

		clearTables 'characters', 'battle_participants'
		insert 'characters', data

		expectedData = Object.clone(data)
		expectedData.health_percent = 50
		expectedData.mana_percent = 25
		expectedData.exp_max = 3000
		expectedData.exp_percent = 0
		expectedData.energy_percent = 50
		expectedData.fight_mode = false

		user = game.getCharacter.sync null, conn, 1
		test.deepEqual user, expectedData, 'should return specific fields by id'
		user = game.getCharacter.sync null, conn, 'someuser'
		test.deepEqual user, expectedData, 'should return specific fields by nickname'

		insert 'battle_participants', character_id: 1
		expectedData.fight_mode = true
		user = game.getCharacter.sync null, conn, 1
		test.deepEqual user, expectedData, 'should return also return id character is in fight'

		user = game.getCharacter.sync null, conn, 2
		test.strictEqual user, null, 'should return null if no such user exists'
		user = game.getCharacter.sync null, conn, 'anotheruser'
		test.strictEqual user, null, 'should return null if no such user exists'
		test.done()

	testErrors: (test) ->
		# What?..
		test.throws(
			-> game.getCharacter.sync conn, 1
			Error
			''
		)
		test.done()


exports.getCharacters = (test) ->
	clearTables 'characters'
	chars = game.getCharacters(conn, 1)
	test.deepEqual chars, [], 'should return no characters if user does not have any'

	insert 'characters', id: 1, player: 1, name: 'Nagibator'
	insert 'characters', id: 2, player: 1, name: 'Ybivator'
	insert 'characters', id: 3, player: 2, name: 'Voskreshator'
	chars = game.getCharacters(conn, 1)
	test.deepEqual chars, [
		{id: 1, name: 'Nagibator'}
		{id: 2, name: 'Ybivator'}
	], 'should return some characters info'
	test.done()


exports.getCharacterItems = (test) ->
	clearTables 'items', 'items_proto'
	insert 'items_proto', id:1, name:'Magic helmet', type:'helmet', coverage:50, strength_max:120, damage: 0
	insert 'items_proto', id:2, name:'Speed greaves', type:'greave', coverage:25, strength_max:110, damage: 10
	insert 'items', id:1, prototype:1, owner:1, strength:100
	insert 'items', id:2, prototype:2, owner:1, strength:100
	insert 'items', id:3, prototype:1, owner:2, strength:110

	items = game.getCharacterItems conn, 1
	test.deepEqual items, [
			{
				id: 1, name: 'Magic helmet', type:'helmet',
				coverage:50, strength:100, strength_max:120, equipped: true, damage: 0
			}
			{
				id: 2, name: 'Speed greaves', type:'greave',
				coverage:25, strength:100, strength_max:110, equipped: true, damage: 10
			}
		] , "should return properties of character's items"
	test.done()



#fixTest = (obj) ->
#	for attr of obj
#		if attr is 'setUp' or attr is 'tearDown'
#			continue
#
#		if obj[attr] instanceof Function
#			obj[attr] = ((origTestFunc, t) -> (test) ->
#					console.log(t)
#					origTestFunc(test)
#				)(obj[attr], attr)
#		else
#			fixTest(obj[attr])
#fixTest exports
