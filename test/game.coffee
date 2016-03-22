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

NS = 'game'; exports[NS] = {}  # namespace
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
sugar = require 'sugar'
mg = require '../lib/migration'
queryUtils = require '../lib/query_utils'

game = requireCovered __dirname, '../lib/game.coffee'

_conn = null
conn = null
query = null


insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) "+
	      "VALUES (#{values.map (v,i) -> '$'+(i+1)+(if v? and typeof v is 'object' then '::json' else '')})",
		values.map((v) -> if v? and typeof v is 'object' then JSON.stringify(v) else v)


exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	mg.migrate.sync mg, _conn

exports[NS].beforeEach = t ->
	conn = transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = t ->
	conn.rollback.sync(conn)


exports[NS].getInitialLocation =
	beforeEach: t ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

	'should return id and parsed ways': t ->
		loc = game.getInitialLocation conn
		test.strictEqual loc.id, 2, 'should return id of initial location'
		test.instanceOf loc.ways, Array, 'should return parsed ways from location'

	'should return error if initial location is not defined': t ->
		query 'UPDATE locations SET initial = 0'
		test.throws(
			-> game.getInitialLocation conn
			Error, 'initial location is not defined'
		)

	'should return error if there is more than one initial location': t ->
		query 'UPDATE locations SET initial = 1 WHERE id = 3'
		test.throws(
			-> game.getInitialLocation conn
			Error, 'there is more than one initial location'
		)


exports[NS].getCharacterLocationId =
	"should return user's location id": t ->
		insert 'characters', id: 1, 'location': 3
		insert 'characters', id: 2, 'location': 1
		test.strictEqual game.getCharacterLocationId.sync(null, conn, 1), 3
		test.strictEqual game.getCharacterLocationId.sync(null, conn, 2), 1

	'should fail if character id is wrong': t ->
		test.throws(
			-> game.getCharacterLocationId.sync(null, conn, -1)
			Error, "wrong character's id",
		)


exports[NS].getCharacterLocation =
	beforeEach: t ->
		insert 'characters', id: 1, location: 3

	'should return location id and ways': t ->
		ways = [
			{target:7, text:'Left'}
			{target:8, text:'Forward'}
			{target:9, text:'Right'}
		]
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: ways

		loc = game.getCharacterLocation.sync(null, conn, 1)
		test.strictEqual loc.id, 3
		test.deepEqual loc.ways, ways

	'should fail on wrong character id': t ->
		test.throws(
			-> game.getCharacterLocation.sync null, conn, -1
			Error, "wrong character's id",
		)

	"should fail if user's location is wrong": t ->
		insert 'locations', id: 1, area: 5
		test.throws(
			-> game.getCharacterLocation.sync null, conn, 1
			Error, "wrong character's id or location",
		)


exports[NS].getCharacterArea =
	beforeEach: t ->
		insert 'characters', id: 1, location: 3

	"should return user's area id and name": t ->
		insert 'locations', id: 3, area: 5, title: 'The Location'
		insert 'areas', id: 5, title: 'London'
		area = game.getCharacterArea.sync null, conn, 1

		test.strictEqual area.id, 5
		test.strictEqual area.title, 'London'

	'should fail on wrong user id': t ->
		test.throws(
			-> game.getCharacterArea.sync null, conn, -1
			Error, "wrong character's id",
		)


exports[NS].isTherePathForCharacterToLocation =
	beforeEach: t ->
		insert 'characters', id: 1, location: 1
		insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
		insert 'locations', id: 2

	'should return true if path exists': t ->
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 2
		test.isTrue can

	'should return false if already on this location': t ->
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
		test.isFalse can

	"should return false if path doesn't exist": t ->
		game.changeLocation.sync null, conn, 1, 2
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
		test.isFalse can


exports[NS]._createBattleBetween =
	'should create battle with correct location, turn and sides': t ->
		locid = 123
		firstSide = [
			{id: 1, initiative:  5}
			{id: 2, initiative: 15}
			{id: 5, initiative: 30}
		]
		secondSide = [
			{id: 6, initiative: 20}
			{id: 7, initiative: 10}
		]

		game._createBattleBetween conn, locid, firstSide, secondSide

		battle = query.row 'SELECT id, location, turn_number FROM battles'
		participants = query.all 'SELECT character_id AS id, index, side FROM battle_participants WHERE battle = $1', [battle.id]

		test.strictEqual battle.location, locid
		test.strictEqual battle.turn_number, 0
		test.deepEqual participants, [
			{id: 5, index: 0, side: 0}
			{id: 6, index: 1, side: 1}
			{id: 2, index: 2, side: 0}
			{id: 7, index: 3, side: 1}
			{id: 1, index: 4, side: 0}
		]


exports[NS]._stopBattle =
	beforeEach: t ->
		insert 'characters', id: 1, autoinvolved_fm: true
		insert 'battles', id: 1
		insert 'battle_participants', battle: 1, character_id: 1
		insert 'battle_participants', battle: 1, character_id: 2

	'should remove battle and free participants': t ->
		game._stopBattle(conn, 1)
		test.strictEqual +query.val("SELECT count(*) FROM battles"), 0, 'should remove battle'
		test.strictEqual +query.val("SELECT count(*) FROM battle_participants"), 0, 'should remove participants'
		test.strictEqual +query.val("SELECT autoinvolved_fm FROM characters WHERE id=1"), 0, 'should uninvolve user'


exports[NS]._leaveBattle =
	beforeEach: t ->
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

	'should update battle but not stop if someone is slill fighting': t ->
		res = game._leaveBattle(conn, 1, 1)
		test.isFalse res.battleEnded

		test.isFalse query.val("SELECT autoinvolved_fm FROM characters WHERE id=1"), 'should uninvolve user'

		rows = query.all "SELECT character_id AS id, index FROM battle_participants WHERE battle = 1 ORDER by id"
		test.deepEqual rows, [
			{id:2, index:0}
			{id:3, index:1}
			{id:6, index:2}
		], 'should update indexes'

	'should stop battle if one side become empty': t ->
		game._leaveBattle(conn, 1, 1)
		res = game._leaveBattle(conn, 1, 3)
		test.isTrue res.battleEnded

		test.isFalse query.val("SELECT autoinvolved_fm FROM characters WHERE id=2"), 'should uninvolve involved'
		test.strictEqual +query.val("SELECT count(*) FROM battles WHERE id = 1"), 0, 'should remove battle'
		test.strictEqual +query.val("SELECT count(*) FROM battle_participants WHERE battle = 1"), 0,
			'should remove participants'

		test.strictEqual +query.val("SELECT count(*) FROM battles"), 1, 'should not affect other battles'
		test.strictEqual +query.val("SELECT count(*) FROM battle_participants"), 2,
			'should not affect other participants'

	'should throw error if unable to find anyone to leave': t ->
		test.throws(
			-> game._leaveBattle(conn, 1, 123)
			Error, "can't find participant character_id=123 in battle #1"
		)


exports[NS].changeLocation =
	beforeEach: t ->
		insert 'characters', id: 1, location: 1, initiative: 50
		insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
		insert 'locations', id: 2

	'should not be attacked on location with peaceful monster': t ->
		insert 'monsters', id: 1, location: 2, attack_chance: 0
		game.changeLocation.sync null, conn, 1, 2

		locid = game.getCharacterLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = game.isInFight.sync(null, conn, 1)
		test.isFalse fm, 'user should not be attacked if monster attack_chance is 0%'

	'should be attacked on location with angry monster': t ->
		insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		insert 'characters', id: 12, location: 2, attack_chance: 100, initiative: 5
		insert 'characters', id: 13, location: 2, attack_chance: 0,   initiative: 10
		game.changeLocation.sync null, conn, 1, 2

		locid = game.getCharacterLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = game.isInFight.sync(null, conn, 1)
		test.isTrue fm, "user should be attacked if at least one monster's attack chance is 100%"

		participantsCount = +query.val 'SELECT count(*) FROM battle_participants'
		test.strictEqual participantsCount, 4, 'all monsters should have been involved'

		userSide = query.val "SELECT side FROM battle_participants WHERE character_id=1"
		for m in query.all("SELECT side FROM battle_participants WHERE character_id!=1")
			test.ok userSide isnt m.side, 'user and monsters should be on different sides'

	'should not be attacked if monster is in another battle': t ->
		insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		insert 'battle_participants', character_id: 11
		game.changeLocation.sync null, conn, 1, 2

		fm = game.isInFight.sync(null, conn, 1)
		test.isFalse fm

	'while in battle':
		beforeEach: t ->
			insert 'battle_participants', character_id: 1

		'should not go anywhere': t ->
			game.changeLocation.sync null, conn, 1, 2
			locid = game.getCharacterLocationId.sync null, conn, 1
			test.strictEqual locid, 1, 'should not change location'

		'should leave battle and change location if force flag is set': t ->
			game.changeLocation.sync null, conn, 1, 2, true
			test.isFalse game.isInFight.sync(null, conn, 1)
			test.strictEqual game.getCharacterLocationId.sync(null, conn, 1), 2

	'when no way to location':
		beforeEach: t ->
			insert 'locations', id: 3

		'should not go anywhere': t ->
			game.changeLocation.sync null, conn, 1, 3
			test.strictEqual game.getCharacterLocationId.sync(null, conn, 1), 1

		'should change location despite all roads if force flag is set': t ->
			game.changeLocation.sync null, conn, 1, 3, true
			test.strictEqual game.getCharacterLocationId.sync(null, conn, 1), 3


exports[NS].goAttack =
	beforeEach: t ->
		insert 'characters', id: 1, location: 1, initiative: 10, player: 1
		insert 'characters', id: 11, location: 1, initiative: 20
		insert 'characters', id: 12, location: 1, initiative: 30

	'should correctly setup battle': t ->
		game.goAttack.sync null, conn, 1

		envolvedMonstersCount = +query.val "SELECT count(*) FROM battle_participants WHERE character_id!=1"
		test.strictEqual envolvedMonstersCount, 2, 'all monsters should have been envolved'

		test.isTrue game.isInFight.sync(null, conn, 1), 'user should be attacking'

	'should not start second battle if user is already in filght': t ->
		game.goAttack.sync null, conn, 1
		envolvedCountBefore = +query.val "SELECT count(*) FROM battle_participants"
		game.goAttack.sync null, conn, 1

		battlesCount = +query.val "SELECT count(*) FROM battles"
		test.strictEqual battlesCount, 1, 'second battle should not be created'

		envolvedCountAfter = +query.val "SELECT count(*) FROM battle_participants"
		test.strictEqual envolvedCountBefore, envolvedCountAfter, 'no more participants should appear'

	'should not invole monster in battle if he is already in fight': t ->
		insert 'battle_participants', character_id: 12
		game.goAttack.sync null, conn, 1

		count = +query.val "SELECT count(*) FROM battle_participants WHERE character_id=12"
		test.strictEqual count, 1, 'should not envolve monster in second battle'

	'should not start battle if location is empty': t ->
		query 'DELETE FROM characters WHERE id != 1'
		game.goAttack.sync null, conn, 1

		fm = game.isInFight.sync(null, conn, 1)
		test.isFalse fm, 'user should not be fighting'

		test.strictEqual +query.val('SELECT count(*) FROM battles'), 0, 'should be no battles'
		test.strictEqual +query.val('SELECT count(*) FROM battle_participants'), 0, 'should be no participants'


exports[NS].goEscape =
	beforeEach: t ->
		insert 'characters', id: 1, autoinvolved_fm: 1
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 1
		insert 'battle_participants', battle: 3, character_id: 1

	'should escape user from battle': t ->
		game.goEscape.sync null, conn, 1
		autoinvolved = query.val 'SELECT autoinvolved_fm FROM characters WHERE id=1'

		test.isFalse game.isInFight.sync(null, conn, 1), 'user should not be attacking'
		test.isFalse autoinvolved, 'user should not be autoinvolved'


exports[NS].getBattleParticipants =
	beforeEach: t ->
		insert 'characters', id: 1,  name: 'SomeUser', player: 2
		insert 'characters', id: 11, name: 'SomeMonster 1'
		insert 'characters', id: 12, name: 'SomeMonster 2'
		insert 'battle_participants', battle: 3, character_id: 1,  side: 1, index: 1
		insert 'battle_participants', battle: 3, character_id: 11, side: 0, index: 0
		insert 'battle_participants', battle: 3, character_id: 12, side: 0, index: 2

	'should return participants with names': t ->
		participants = game.getBattleParticipants.sync(null, conn, 1)
		test.deepEqual participants, [
			{ character_id: 11, name: 'SomeMonster 1', side: 0, index: 0, player: null }
			{ character_id: 1,  name: 'SomeUser',      side: 1, index: 1, player: 2    }
			{ character_id: 12, name: 'SomeMonster 2', side: 0, index: 2, player: null }
		]


exports[NS]._lockAndGetStatsForBattle =
	beforeEach: t ->
		insert 'characters', id: 1,  power: 100
		insert 'characters', id: 11, power: 200
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 1,  side: 1
		insert 'battle_participants', battle: 3, character_id: 11, side: 2

		#select t.relname,mode,granted from pg_locks l, pg_stat_all_tables t where l.relation=t.relid;

	'should return nesessary data': t ->
		for [battleId, stats] in [
			[1, {side: 1, power: 100, battle: 3}]
			[11, {side: 2, power: 200, battle: 3}]
		]
			tx = transaction(conn)
			user = game._lockAndGetStatsForBattle(tx, battleId)
			test.deepEqual user, stats
			tx.rollback.sync(tx)


exports[NS]._hitItem =
	"strong item should absorb all damage and get damaged a bit": t ->
		insert 'items', id: 1, strength: 100
		item = query.row 'SELECT id, strength FROM items'

		delta = game._hitItem(conn, 80, item)
		test.strictEqual delta, 80, "should reduce all attacker's power"
		test.strictEqual query.val("SELECT strength FROM items"), 20, "should reduce item's strength"

	"weak item should absorb some damage and got broken": t ->
		insert 'items', id: 1, strength: 20
		item = query.row 'SELECT id, strength FROM items'

		delta = game._hitItem(conn, 80, item)
		test.strictEqual delta, 20, "should reduce part of attacker's power"
		test.strictEqual query.val("SELECT strength FROM items"), 0, "should break item down"


exports[NS]._hitAndGetHealth =
	beforeEach: t ->
		insert 'characters', id: 1,  health: 1000, defense: 50
		insert 'characters', id: 11, health: 1000, defense: 50

	'without shield and armor':
		'should deal correct amounts of damage': t ->
			power = 70
			minDmg = (power - 50) / 2 * 0.8
			maxDmg = (power - 50) / 2 * 1.2
			victim_id = 1

			damages = {}
			prevHP = 1000

			for i in [0..100]
				hp = game._hitAndGetHealth conn, victim_id, power
				hpActual = query.val "SELECT health FROM characters WHERE id=$1", [victim_id]
				test.strictEqual hp, hpActual, "should return current characters's health"

				dmg = prevHP - hp
				test.ok minDmg <= dmg <= maxDmg, "dealed damage should be in fixed range"

				damages[dmg] = true
				prevHP = hp

			test.isAbove Object.keys(damages).length, 1, "should deal different amounts of damage"
			test.ok damages[minDmg], 'should sometimes deal minimal damage'
			test.ok damages[maxDmg], 'should sometimes deal maximal damage'

		"should not change health if defense is greater than damage": t ->
			query "UPDATE characters SET defense = 9001"
			power = 70
			victim_id = 1
			hpAfter = game._hitAndGetHealth conn, victim_id, power
			test.strictEqual hpAfter, 1000


	'when victim has armor':
		beforeEach: t ->
			power = 70
			this.damages = null

			userHP = (tx) -> queryUtils.getFor(tx).val 'SELECT health FROM characters WHERE id=1'
			totalStr = (tx) -> queryUtils.getFor(tx).val 'SELECT SUM(strength) FROM items'

			this.performSomeAttacks = ->
				this.damages = {}
				tx = transaction(conn)
				for i in [0..20]
					prevHP = userHP(tx)
					prevSt = totalStr(tx)

					hp = game._hitAndGetHealth tx, 1, power
					dmg = prevHP - hp
					this.damages[dmg] = true

					if dmg is 0
						test.ok prevSt > totalStr(tx), 'should reduce armor strength if damage was blocked'
				tx.rollback.sync(tx)

			insert 'items_proto', id:1, name: 'breastplate', coverage:25
			insert 'items_proto', id:2, name: 'greave', coverage:25
			insert 'items', prototype:1, owner:1, strength:10000, equipped: true
			insert 'items', prototype:2, owner:1, strength:10000, equipped: true

		'should block some of attacks if total armor coverage is between 0% and 100%': t ->
			this.performSomeAttacks()
			test.ok this.damages[0], 'armor should block some attacks'
			test.ok Object.keys(this.damages).length > 1, 'armor should not block all attacks'

		'should block all if total armor coverage is 100%': t ->
			query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
			this.performSomeAttacks()
			test.deepEqual this.damages, {'0': true}

		'should not block anything if total armor coverage is 0%': t ->
			query 'UPDATE items_proto SET coverage = 0'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

		'armor should not block anything if it is broken': t ->
			query 'UPDATE items_proto SET coverage = 50'
			query 'UPDATE items SET strength = 0'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

		'armor should not block anything if it is unequipped': t ->
			query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
			query 'UPDATE items SET strength = 10000'
			query 'UPDATE items SET equipped = false'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

	'when victim has shield': t ->
		insert 'items_proto', id:1, name: 'The Shield', coverage:100, type: 'shield'
		insert 'items_proto', id:2, name: 'greave', coverage:100
		insert 'items', id:10, prototype:1, owner:1, strength:100, equipped: true
		insert 'items', id:20, prototype:2, owner:1, strength:100, equipped: true

		power = 120
		shield = (tx) -> queryUtils.getFor(tx).row('SELECT strength FROM items WHERE id=10')
		greave = (tx) -> queryUtils.getFor(tx).row('SELECT strength FROM items WHERE id=20')

		# shield with 100% coverage
		for i in [0...5]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			test.strictEqual hp, 1000, 'both shield and armor should block damage'
			test.strictEqual shield(tx).strength, 0, 'shield should block damage first'
			test.strictEqual greave(tx).strength, 80, 'armor should block damage not blocked by shield'
			tx.rollback.sync(tx)

		# shield with 50% coverage
		query 'UPDATE items_proto SET coverage = 50'
		query 'UPDATE items SET strength = 1000'
		hits = shield:0, notShield:0
		for i in [0...40]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			if shield(tx).strength < 1000 then hits.shield++
			if greave(tx).strength < 1000 then hits.notShield++
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
			test.strictEqual shield(tx).strength, 1000, "shield should not block anything if it's coverage is 0%"
			tx.rollback.sync(tx)

		# shield is not equipped
		query 'UPDATE items_proto SET coverage = 100'
		query 'UPDATE items SET equipped = false WHERE id = 10'
		query 'UPDATE items SET strength = 100'
		for i in [0...5]
			tx = transaction(conn)
			hp = game._hitAndGetHealth tx, 1, power
			test.strictEqual shield(tx).strength, 100, 'shield should receive no damage if not equipped'
			test.strictEqual greave(tx).strength, 0, 'armor should receive all damage if shield is not equipped'
			tx.rollback.sync(tx)


exports[NS]._handleDeathInBattle =
	beforeEach: t ->
		insert 'locations', id: 5, initial: 1
		insert 'characters', id: 1, health: 0, health_max: 1000, player: 1, exp: 990, level: 1
		insert 'characters', id: 2, health: 0, health_max: 1000, player: 2, exp: 0, level: 2
		insert 'characters', id: 11, player: null, level: 3

	'should respawn killed user, restore his health and give some expa to killer': t ->
		game._handleDeathInBattle conn, 1, 2
		test.strictEqual query.val('SELECT location FROM characters WHERE id=1'), 5,
			'should return user back to initial location'
		test.strictEqual query.val('SELECT health FROM characters WHERE id=1'), 1000,
			"should restore user's health"
		test.strictEqual query.val('SELECT exp FROM characters WHERE id=2'), 0,
			"should not add experience for PK"
		test.strictEqual query.val('SELECT level FROM characters WHERE id=2'), 2,
			"should not add experience for PK"

	'should remove killed monster and give expa to hunter': t ->
		game._handleDeathInBattle conn, 11, 1
		test.strictEqual +query.val('SELECT count(*) FROM characters'), 2, 'should remove monster'
		test.strictEqual query.val('SELECT exp FROM characters WHERE id=1'), (990 + 50+10) - 1000,
			"should add some experience to monster slayer"
		test.strictEqual query.val('SELECT level FROM characters WHERE id=1'), 2,
			"should account for level-ups"



exports[NS]._hit =
	beforeEach: t ->
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

	'hitting without equipment': t ->
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

	'hitting with different weapons': t ->
		['shield', 'weapon-one-handed', 'no-such-item-but-why-not'].forEach (type) ->
			query 'DELETE FROM items_proto'
			query 'DELETE FROM items'
			insert 'items_proto', id:1, name: 'Ogrebator 4000', coverage:100, type: type, damage: 100
			insert 'items', id:10, prototype:1, owner:1, strength:100, equipped:true

			# normal hit with item
			result = game._hit conn, 1, 5, 10
			test.strictEqual result.state, 'ok', 'should hit successfully'
			hp = query.val 'SELECT health FROM characters WHERE id = 5'
			test.ok hp < 500-40, 'should deal more damage than barehanded player can'

			# try hit with 0-damage item
			query "UPDATE items_proto SET damage = 0"
			result = game._hit conn, 1, 5, 10
			test.deepEqual result,
					state: 'cancelled'
					reason: "can't hit with this item"
				'should cancel hit and describe reason if item has no dmage gain'

			# try hit with wrong item
			result = game._hit conn, 1, 5, 123
			test.deepEqual result,
					state: 'cancelled'
					reason: 'weapon item not found'
				'should cancel hit and describe reason if item id is wrong'


exports[NS].hitOpponent =
	beforeEach: t ->
		insert 'characters', id: 1, name: 'SomeUser', power: 20, defense: 10, health: 1000, player: 1
		insert 'characters', id: 4, name: 'SomeMonster 1', power: 20, defense: 10, health: 1000
		insert 'characters', id: 5, name: 'SomeMonster 2', power: 20, defense: 10, health: 1000
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, character_id: 4, side: 1, index: 1
		insert 'battle_participants', battle: 3, character_id: 5, side: 1, index: 2
		insert 'battle_participants', battle: 3, character_id: 1, side: 0, index: 0

	'normal attack': t ->
		minDmg = (20-10)/2 * 0.8

		game.hitOpponent conn, 1, 4
		hp = query.val 'SELECT health FROM characters WHERE id = 4'
		test.isAtMost hp, 1000-minDmg, 'should hit'
		hp = query.val 'SELECT health FROM characters WHERE id = 1'
		test.isAtMost hp, 1000-minDmg*2, 'victims should hit back'

		query 'UPDATE characters SET health=1 WHERE id = 4'
		query 'UPDATE characters SET health=1000 WHERE id = 1'
		game.hitOpponent conn, 1, 4
		hp = query.val 'SELECT health FROM characters WHERE id = 1'
		test.isAtMost hp, 1000-minDmg, 'only alive opponents should hit back'

	'defeating target': t ->
		query "DELETE FROM battle_participants WHERE character_id = 5"
		query 'UPDATE characters SET health=1 WHERE id=4'

		game.hitOpponent conn, 1, 4
		count = +query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle defeating last opponent'

	'defeated by target': t ->
		query 'UPDATE characters SET health = 1'
		game.hitOpponent conn, 1, 4
		count = +query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle when defeated by opponent'


exports[NS].getNearbyUsers =
	beforeEach: t ->
		d = new Date()
		now = (d.getFullYear() + 1) + '-' + (d.getMonth() + 1) + '-' + d.getDate()
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

	'should return all online users on this location': t ->
		users = game.getNearbyUsers.sync null, conn, 1, 1
		test.deepEqual users, [
			{ id: 2, name: 'otheruser' }
			{ id: 3, name: 'thirduser' }
		]

		users = game.getNearbyUsers.sync null, conn, 5, 2
		test.deepEqual users, []


exports[NS].getNearbyMonsters =
	beforeEach: t ->
		insert 'characters', id: 1, location: 1, player: 1
		insert 'characters', id: 2, location: 2, player: 2
		insert 'characters', id: 11, location: 1, attack_chance: 42, name: 'The Creature of Unimaginable Horror'
		insert 'characters', id: 12, location: 2
		insert 'characters', id: 13, location: 2

	'should return nearby monsters': t ->
		monsters = game.getNearbyMonsters.sync null, conn, 1
		test.strictEqual monsters.length, 1, 'should not return excess monsters'
		test.strictEqual monsters[0].attack_chance, 42, "should return monster's info"
		test.strictEqual monsters[0].name, 'The Creature of Unimaginable Horror', 'should return prototype info too'


exports[NS].isInFight =
	beforeEach: t ->
		insert 'characters', id: 2
		insert 'characters', id: 4
		insert 'battle_participants', character_id: 4

	'should return if user in in fight mode': t ->
		test.isFalse game.isInFight.sync(null, conn, 2)
		test.isTrue game.isInFight.sync(null, conn, 4)


exports[NS].isAutoinvolved =
	beforeEach: t ->
		insert 'characters', id: 2, autoinvolved_fm: false
		insert 'characters', id: 4, autoinvolved_fm: true

	'should return if user was attacked or not': t ->
		test.isFalse game.isAutoinvolved.sync(null, conn, 2)
		test.isTrue game.isAutoinvolved.sync(null, conn, 4)


exports[NS].uninvolve =
	beforeEach: t ->
		insert 'characters', id: 1, autoinvolved_fm: true
		insert 'battle_participants', character_id: 1

	'should uninvole user': t ->
		game.uninvolve.sync null, conn, 1
		test.isFalse query.val('SELECT autoinvolved_fm FROM characters WHERE id=1')
		test.isTrue game.isInFight.sync(null, conn, 1), 'should not disable fight mode'


exports[NS].expForKill =
	'should give regular expa for killing same level': ->
		test.strictEqual game.expForKill(10, 10), 50

	'should give more expa for stronger opponenet': ->
		test.strictEqual game.expForKill(10, 12), 50+10

	'should give less expa for weaker opponenet': ->
		test.strictEqual game.expForKill(10, 7), 50-15

	'should not take expa for killing newbies': ->
		test.strictEqual game.expForKill(100, 0), 0


exports[NS].getCharacter =
	beforeEach: t ->
		this.data =
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
			race: 'elf'
			gender: 'female'

		insert 'characters', this.data

		this.expectedData = Object.clone(this.data)
		this.expectedData.exp_max = 3000
		this.expectedData.fight_mode = false

	'should return character info by id': t ->
		user = game.getCharacter.sync null, conn, 1
		test.deepEqual user, this.expectedData

	'should return character info by nickname': t ->
		user = game.getCharacter.sync null, conn, 'someuser'
		test.deepEqual user, this.expectedData

	'should return also if character is in fight': t ->
		insert 'battle_participants', character_id: 1
		this.expectedData.fight_mode = true

		user = game.getCharacter.sync null, conn, 1
		test.deepEqual user, this.expectedData

	'should return null if no such user exists': t ->
		test.isNull game.getCharacter.sync(null, conn, 2)
		test.isNull game.getCharacter.sync(null, conn, 'anotheruser')


exports[NS].getCharacters =
	'should return some characters info': t ->
		insert 'characters', id: 1, player: 1, name: 'Nagibator', race: 'orc', gender: 'male'
		insert 'characters', id: 2, player: 1, name: 'Ybivator', race: 'elf', gender: 'female'
		insert 'characters', id: 3, player: 2, name: 'Voskreshator', race: 'human', gender: 'male'
		chars = game.getCharacters(conn, 1)
		test.deepEqual chars, [
			{ id: 1, name: 'Nagibator', race: 'orc', gender: 'male' }
			{ id: 2, name: 'Ybivator', race: 'elf', gender: 'female' }
		]

	'should return no characters if user does not have any': t ->
		chars = game.getCharacters(conn, 1)
		test.deepEqual chars, []


exports[NS].getCharacterItems =
	beforeEach: t ->
		insert 'items_proto',
			id:1, name:'Magic helmet', type:'helmet', armor_class: 'plate', coverage:50, strength_max:120, damage: 0
		insert 'items_proto',
			id:2, name:'Speed greaves', type:'greave', armor_class: 'leather', coverage:25, strength_max:110, damage: 10
		insert 'items_proto',
			id:3, name:'Mighty sword', type:'weapon-one-handed', class:'normal', kind:'sword'
			coverage: null, strength_max:110, damage: 1000
		insert 'items', id:1, prototype:1, owner:1, strength:100
		insert 'items', id:2, prototype:2, owner:1, strength:100
		insert 'items', id:3, prototype:1, owner:2, strength:110
		insert 'items', id:4, prototype:3, owner:1, strength:110

	"should return properties of character's items": t ->
		items = game.getCharacterItems conn, 1
		test.deepEqual items, [
			{
				id: 1, name: 'Magic helmet', type:'helmet', class: null, kind: null,
				armor_class: 'plate', coverage:50, strength:100, strength_max:120, equipped: true, damage: 0
			}
			{
				id: 2, name: 'Speed greaves', type:'greave', class: null, kind: null,
				armor_class: 'leather', coverage:25, strength:100, strength_max:110, equipped: true, damage: 10
			}
			{
				id: 4, name:'Mighty sword', type:'weapon-one-handed', class:'normal', kind:'sword',
				armor_class: null, coverage: null, strength:110, strength_max:110, damage: 1000, equipped: true
			}
		]
