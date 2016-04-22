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
{test, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll
sugar = require 'sugar'
mg = require '../lib/migration'
queryUtils = require '../lib/query_utils'

game = requireCovered __dirname, '../lib/game.coffee'

_conn = null
conn = null
query = null


insert = (table, fields) ->
	queryUtils.unsafeInsert conn, table, fields


exports[NS].before = async ->
	_conn = promisifyAll anyDB.createConnection(config.DATABASE_URL_TEST)
	await mg.migrate _conn

exports[NS].beforeEach = async ->
	conn = promisifyAll transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = async ->
	await conn.rollbackAsync()


exports[NS].getInitialLocation =
	beforeEach: async ->
		await insert 'locations', id: 1
		await insert 'locations', id: 2, initial: 1
		await insert 'locations', id: 3

	'should return id and parsed ways': async ->
		loc = await game.getInitialLocation conn
		test.strictEqual loc.id, 2, 'should return id of initial location'
		test.instanceOf loc.ways, Array, 'should return parsed ways from location'

	'should return error if initial location is not defined': async ->
		await query 'UPDATE locations SET initial = 0'
		test.throws(
			-> await game.getInitialLocation conn
			Error, 'initial location is not defined'
		)

	'should return error if there is more than one initial location': async ->
		await query 'UPDATE locations SET initial = 1 WHERE id = 3'
		test.throws(
			-> await game.getInitialLocation conn
			Error, 'there is more than one initial location'
		)


exports[NS].getCharacterLocationId =
	"should return user's location id": async ->
		await insert 'characters', id: 1, 'location': 3
		await insert 'characters', id: 2, 'location': 1
		test.strictEqual await(game.getCharacterLocationId(conn, 1)), 3
		test.strictEqual await(game.getCharacterLocationId(conn, 2)), 1

	'should fail if character id is wrong': async ->
		test.throws(
			-> await game.getCharacterLocationId conn, -1
			Error, "wrong character's id",
		)


exports[NS].getCharacterLocation =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 3

	'should return location id and ways': async ->
		ways = [
			{target:7, text:'Left'}
			{target:8, text:'Forward'}
			{target:9, text:'Right'}
		]
		await insert 'locations', id: 3, area: 5, title: 'The Location', ways: ways

		loc = await game.getCharacterLocation conn, 1
		test.strictEqual loc.id, 3
		test.deepEqual loc.ways, ways

	'should fail on wrong character id': async ->
		test.throws(
			-> await game.getCharacterLocation conn, -1
			Error, "wrong character's id",
		)

	"should fail if user's location is wrong": async ->
		await insert 'locations', id: 1, area: 5
		test.throws(
			-> await game.getCharacterLocation conn, 1
			Error, "wrong character's id or location",
		)


exports[NS].getCharacterArea =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 3

	"should return user's area id and name": async ->
		await insert 'locations', id: 3, area: 5, title: 'The Location'
		await insert 'areas', id: 5, title: 'London'
		area = await game.getCharacterArea conn, 1

		test.strictEqual area.id, 5
		test.strictEqual area.title, 'London'

	'should fail on wrong user id': async ->
		test.throws(
			-> await game.getCharacterArea conn, -1
			Error, "wrong character's id",
		)


exports[NS].isTherePathForCharacterToLocation =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 1
		await insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
		await insert 'locations', id: 2

	'should return true if path exists': async ->
		can = await game.isTherePathForCharacterToLocation conn, 1, 2
		test.isTrue can

	'should return false if already on this location': async ->
		can = await game.isTherePathForCharacterToLocation conn, 1, 1
		test.isFalse can

	"should return false if path doesn't exist": async ->
		await game.changeLocation conn, 1, 2
		can = await game.isTherePathForCharacterToLocation conn, 1, 1
		test.isFalse can


exports[NS]._createBattleBetween =
	'should create battle with correct location, turn and sides': async ->
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

		await game._createBattleBetween conn, locid, firstSide, secondSide

		battle = await query.row 'SELECT id, location, turn_number FROM battles'
		participants = await query.all 'SELECT character_id AS id, index, side '+
			'FROM battle_participants WHERE battle = $1', [battle.id]

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
	beforeEach: async ->
		await insert 'characters', id: 1, autoinvolved_fm: true
		await insert 'battles', id: 1
		await insert 'battle_participants', battle: 1, character_id: 1
		await insert 'battle_participants', battle: 1, character_id: 2

	'should remove battle and free participants': async ->
		await game._stopBattle(conn, 1)
		test.strictEqual +(await query.val "SELECT count(*) FROM battles"), 0, 'should remove battle'
		test.strictEqual +(await query.val "SELECT count(*) FROM battle_participants"), 0, 'should remove participants'
		test.strictEqual +(await query.val "SELECT autoinvolved_fm FROM characters WHERE id=1"), 0, 'should uninvolve user'


exports[NS]._leaveBattle =
	beforeEach: async ->
		await insert 'characters', id: 1, autoinvolved_fm: 1
		await insert 'characters', id: 2, autoinvolved_fm: 1
		await insert 'battles', id: 1
		await insert 'battle_participants', battle: 1, character_id: 1, side: 0, index: 1
		await insert 'battle_participants', battle: 1, character_id: 2, side: 1, index: 0
		await insert 'battle_participants', battle: 1, character_id: 3, side: 0, index: 2
		await insert 'battle_participants', battle: 1, character_id: 6, side: 1, index: 3
		await insert 'battles', id: 2
		await insert 'battle_participants', battle: 2, character_id: 4, side: 0, index: 0
		await insert 'battle_participants', battle: 2, character_id: 5, side: 1, index: 1

	'should update battle but not stop if someone is slill fighting': async ->
		res = await game._leaveBattle(conn, 1, 1)
		test.isFalse res.battleEnded

		test.isFalse (await query.val "SELECT autoinvolved_fm FROM characters WHERE id=1"), 'should uninvolve user'

		rows = await query.all "SELECT character_id AS id, index FROM battle_participants WHERE battle = 1 ORDER by id"
		test.deepEqual rows, [
			{id:2, index:0}
			{id:3, index:1}
			{id:6, index:2}
		], 'should update indexes'

	'should stop battle if one side become empty': async ->
		await game._leaveBattle(conn, 1, 1)
		res = await game._leaveBattle(conn, 1, 3)
		test.isTrue res.battleEnded

		test.isFalse (await query.val "SELECT autoinvolved_fm FROM characters WHERE id=2"), 'should uninvolve involved'
		test.strictEqual +(await query.val "SELECT count(*) FROM battles WHERE id = 1"), 0, 'should remove battle'
		test.strictEqual +(await query.val "SELECT count(*) FROM battle_participants WHERE battle = 1"), 0,
			'should remove participants'

		test.strictEqual +(await query.val "SELECT count(*) FROM battles"), 1, 'should not affect other battles'
		test.strictEqual +(await query.val "SELECT count(*) FROM battle_participants"), 2,
			'should not affect other participants'

	'should throw error if unable to find anyone to leave': async ->
		test.throws(
			-> await game._leaveBattle(conn, 1, 123)
			Error, "can't find participant character_id=123 in battle #1"
		)


exports[NS].changeLocation =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 1, initiative: 50
		await insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
		await insert 'locations', id: 2

	'should not be attacked on location with peaceful monster': async ->
		await insert 'monsters', id: 1, location: 2, attack_chance: 0
		await game.changeLocation conn, 1, 2

		locid = await game.getCharacterLocationId conn, 1
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = await game.isInFight conn, 1
		test.isFalse fm, 'user should not be attacked if monster attack_chance is 0%'

	'should be attacked on location with angry monster': async ->
		await insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		await insert 'characters', id: 12, location: 2, attack_chance: 100, initiative: 5
		await insert 'characters', id: 13, location: 2, attack_chance: 0,   initiative: 10
		await game.changeLocation conn, 1, 2

		locid = await game.getCharacterLocationId conn, 1
		test.strictEqual locid, 2, 'user should have moved to new location'

		fm = await game.isInFight conn, 1
		test.isTrue fm, "user should be attacked if at least one monster's attack chance is 100%"

		participantsCount = + await query.val 'SELECT count(*) FROM battle_participants'
		test.strictEqual participantsCount, 4, 'all monsters should have been involved'

		userSide = query.val "SELECT side FROM battle_participants WHERE character_id=1"
		for m in query.all("SELECT side FROM battle_participants WHERE character_id!=1")
			test.ok userSide isnt m.side, 'user and monsters should be on different sides'

	'should not be attacked if monster is in another battle': async ->
		await insert 'characters', id: 11, location: 2, attack_chance: 100, initiative: 100
		await insert 'battle_participants', character_id: 11
		await game.changeLocation conn, 1, 2

		fm = await game.isInFight conn, 1
		test.isFalse fm

	'while in battle':
		beforeEach: async ->
			await insert 'battle_participants', character_id: 1

		'should not go anywhere': async ->
			await game.changeLocation conn, 1, 2
			locid = await game.getCharacterLocationId conn, 1
			test.strictEqual locid, 1, 'should not change location'

		'should leave battle and change location if force flag is set': async ->
			await game.changeLocation conn, 1, 2, true
			test.isFalse await game.isInFight conn, 1
			test.strictEqual await(game.getCharacterLocationId(conn, 1)), 2

	'when no way to location':
		beforeEach: async ->
			await insert 'locations', id: 3

		'should not go anywhere': async ->
			await game.changeLocation conn, 1, 3
			test.strictEqual await(game.getCharacterLocationId conn, 1), 1

		'should change location despite all roads if force flag is set': async ->
			await game.changeLocation conn, 1, 3, true
			test.strictEqual await(game.getCharacterLocationId conn, 1), 3


exports[NS].goAttack =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 1, initiative: 10, player: 1
		await insert 'characters', id: 11, location: 1, initiative: 20
		await insert 'characters', id: 12, location: 1, initiative: 30

	'should correctly setup battle': async ->
		await game.goAttack conn, 1

		envolvedMonstersCount = + await query.val "SELECT count(*) FROM battle_participants WHERE character_id!=1"
		test.strictEqual envolvedMonstersCount, 2, 'all monsters should have been envolved'

		test.isTrue await(game.isInFight conn, 1), 'user should be attacking'

	'should not start second battle if user is already in filght': async ->
		await game.goAttack conn, 1
		envolvedCountBefore = + await query.val "SELECT count(*) FROM battle_participants"
		await game.goAttack conn, 1

		battlesCount = + await query.val "SELECT count(*) FROM battles"
		test.strictEqual battlesCount, 1, 'second battle should not be created'

		envolvedCountAfter = + await query.val "SELECT count(*) FROM battle_participants"
		test.strictEqual envolvedCountBefore, envolvedCountAfter, 'no more participants should appear'

	'should not invole monster in battle if he is already in fight': async ->
		await insert 'battle_participants', character_id: 12
		await game.goAttack conn, 1

		count = + await query.val "SELECT count(*) FROM battle_participants WHERE character_id=12"
		test.strictEqual count, 1, 'should not envolve monster in second battle'

	'should not start battle if location is empty': async ->
		await query 'DELETE FROM characters WHERE id != 1'
		await game.goAttack conn, 1

		fm = await game.isInFight conn, 1
		test.isFalse fm, 'user should not be fighting'

		test.strictEqual +(await query.val 'SELECT count(*) FROM battles'), 0, 'should be no battles'
		test.strictEqual +(await query.val 'SELECT count(*) FROM battle_participants'), 0, 'should be no participants'


exports[NS].goEscape =
	beforeEach: async ->
		await insert 'characters', id: 1, autoinvolved_fm: 1
		await insert 'battles', id: 3
		await insert 'battle_participants', battle: 3, character_id: 1
		await insert 'battle_participants', battle: 3, character_id: 1

	'should escape user from battle': async ->
		await game.goEscape conn, 1
		autoinvolved = await query.val 'SELECT autoinvolved_fm FROM characters WHERE id=1'

		test.isFalse await(game.isInFight conn, 1), 'user should not be attacking'
		test.isFalse autoinvolved, 'user should not be autoinvolved'


exports[NS].getBattleParticipants =
	beforeEach: async ->
		await insert 'characters', id: 1,  name: 'SomeUser', player: 2
		await insert 'characters', id: 11, name: 'SomeMonster 1'
		await insert 'characters', id: 12, name: 'SomeMonster 2'
		await insert 'battle_participants', battle: 3, character_id: 1,  side: 1, index: 1
		await insert 'battle_participants', battle: 3, character_id: 11, side: 0, index: 0
		await insert 'battle_participants', battle: 3, character_id: 12, side: 0, index: 2

	'should return participants with names': async ->
		participants = await game.getBattleParticipants conn, 1
		test.deepEqual participants, [
			{ character_id: 11, name: 'SomeMonster 1', side: 0, index: 0, player: null }
			{ character_id: 1,  name: 'SomeUser',      side: 1, index: 1, player: 2    }
			{ character_id: 12, name: 'SomeMonster 2', side: 0, index: 2, player: null }
		]


exports[NS]._lockAndGetStatsForBattle =
	beforeEach: async ->
		await insert 'characters', id: 1,  power: 100
		await insert 'characters', id: 11, power: 200
		await insert 'battles', id: 3
		await insert 'battle_participants', battle: 3, character_id: 1,  side: 1
		await insert 'battle_participants', battle: 3, character_id: 11, side: 2

		#select t.relname,mode,granted from pg_locks l, pg_stat_all_tables t where l.relation=t.relid;

	'should return nesessary data': async ->
		for [battleId, stats] in [
			[1, {side: 1, power: 100, battle: 3}]
			[11, {side: 2, power: 200, battle: 3}]
		]
			tx = promisifyAll transaction(conn)
			user = await game._lockAndGetStatsForBattle(tx, battleId)
			test.deepEqual user, stats
			await tx.rollbackAsync()


exports[NS]._hitItem =
	"strong item should absorb all damage and get damaged a bit": async ->
		await insert 'items', id: 1, strength: 100
		item = await query.row 'SELECT id, strength FROM items'

		delta = await game._hitItem(conn, 80, item)
		test.strictEqual delta, 80, "should reduce all attacker's power"
		test.strictEqual (await query.val "SELECT strength FROM items"), 20, "should reduce item's strength"

	"weak item should absorb some damage and got broken": async ->
		await insert 'items', id: 1, strength: 20
		item = await query.row 'SELECT id, strength FROM items'

		delta = await game._hitItem(conn, 80, item)
		test.strictEqual delta, 20, "should reduce part of attacker's power"
		test.strictEqual (await query.val "SELECT strength FROM items"), 0, "should break item down"


exports[NS]._hitAndGetHealth =
	beforeEach: async ->
		await insert 'characters', id: 1,  health: 1000, defense: 50
		await insert 'characters', id: 11, health: 1000, defense: 50

	'without shield and armor':
		'should deal correct amounts of damage': async ->
			power = 70
			minDmg = (power - 50) / 2 * 0.8
			maxDmg = (power - 50) / 2 * 1.2
			victim_id = 1

			damages = {}
			prevHP = 1000

			for i in [0..100]
				hp = await game._hitAndGetHealth conn, victim_id, power
				hpActual = await query.val "SELECT health FROM characters WHERE id=$1", [victim_id]
				test.strictEqual hp, hpActual, "should return current characters's health"

				dmg = prevHP - hp
				test.ok minDmg <= dmg <= maxDmg, "dealed damage should be in fixed range"

				damages[dmg] = true
				prevHP = hp

			test.isAbove Object.keys(damages).length, 1, "should deal different amounts of damage"
			test.ok damages[minDmg], 'should sometimes deal minimal damage'
			test.ok damages[maxDmg], 'should sometimes deal maximal damage'

		"should not change health if defense is greater than damage": async ->
			await query "UPDATE characters SET defense = 9001"
			power = 70
			victim_id = 1
			hpAfter = await game._hitAndGetHealth conn, victim_id, power
			test.strictEqual hpAfter, 1000


	'when victim has armor':
		beforeEach: async ->
			power = 70
			this.damages = null

			userHP = (tx) -> queryUtils.getFor(tx).val 'SELECT health FROM characters WHERE id=1'
			totalStr = (tx) -> queryUtils.getFor(tx).val 'SELECT SUM(strength) FROM items'

			this.performSomeAttacks = ->
				this.damages = {}
				tx = promisifyAll transaction(conn)
				for i in [0..20]
					prevHP = await userHP(tx)
					prevSt = await totalStr(tx)

					hp = await game._hitAndGetHealth tx, 1, power
					dmg = prevHP - hp
					this.damages[dmg] = true

					if dmg is 0
						test.ok prevSt > (await totalStr tx), 'should reduce armor strength if damage was blocked'
				await tx.rollbackAsync()

			await insert 'items_proto', id:1, name: 'breastplate', coverage:25
			await insert 'items_proto', id:2, name: 'greave', coverage:25
			await insert 'items', prototype:1, owner:1, strength:10000, equipped: true
			await insert 'items', prototype:2, owner:1, strength:10000, equipped: true

		'should block some of attacks if total armor coverage is between 0% and 100%': async ->
			this.performSomeAttacks()
			test.ok this.damages[0], 'armor should block some attacks'
			test.ok Object.keys(this.damages).length > 1, 'armor should not block all attacks'

		'should block all if total armor coverage is 100%': async ->
			await query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
			this.performSomeAttacks()
			test.deepEqual this.damages, {'0': true}

		'should not block anything if total armor coverage is 0%': async ->
			await query 'UPDATE items_proto SET coverage = 0'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

		'armor should not block anything if it is broken': async ->
			await query 'UPDATE items_proto SET coverage = 50'
			await query 'UPDATE items SET strength = 0'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

		'armor should not block anything if it is unequipped': async ->
			await query 'UPDATE items_proto SET coverage = 75 WHERE id = 2'
			await query 'UPDATE items SET strength = 10000'
			await query 'UPDATE items SET equipped = false'
			this.performSomeAttacks()
			test.ok 0 not of this.damages

	'when victim has shield': async ->
		await insert 'items_proto', id:1, name: 'The Shield', coverage:100, type: 'shield'
		await insert 'items_proto', id:2, name: 'greave', coverage:100
		await insert 'items', id:10, prototype:1, owner:1, strength:100, equipped: true
		await insert 'items', id:20, prototype:2, owner:1, strength:100, equipped: true

		power = 120
		shield = (tx) -> queryUtils.getFor(tx).row('SELECT strength FROM items WHERE id=10')
		greave = (tx) -> queryUtils.getFor(tx).row('SELECT strength FROM items WHERE id=20')

		# shield with 100% coverage
		for i in [0...5]
			tx = promisifyAll transaction(conn)
			hp = await game._hitAndGetHealth tx, 1, power
			test.strictEqual hp, 1000, 'both shield and armor should block damage'
			test.strictEqual (await shield tx).strength, 0, 'shield should block damage first'
			test.strictEqual (await greave tx).strength, 80, 'armor should block damage not blocked by shield'
			await tx.rollbackAsync()

		# shield with 50% coverage
		await query 'UPDATE items_proto SET coverage = 50'
		await query 'UPDATE items SET strength = 1000'
		hits = shield:0, notShield:0
		for i in [0...40]
			tx = promisifyAll transaction(conn)#, filter: (name) -> name in ['query', 'rollback']
			hp = await game._hitAndGetHealth tx, 1, power
			if (await shield tx).strength < 1000 then hits.shield++
			if (await greave tx).strength < 1000 then hits.notShield++
			if hp < 1000 then hits.notShield++
			await tx.rollbackAsync()
		test.isAbove hits.shield, 0, "shield should block some hits if it's coverage is not 100%"
		test.isAbove hits.notShield, 0, "but should not block all hits"
		test.strictEqual hits.shield+hits.notShield, 40, 'all attacks should hit something'

		# shield with 0% coverage
		await query 'UPDATE items_proto SET coverage = 0 WHERE id = 1'
		for i in [0...40]
			tx = promisifyAll transaction(conn)#, filter: (name) -> name in ['query', 'rollback']
			hp = await game._hitAndGetHealth tx, 1, power
			test.strictEqual (await shield tx).strength, 1000, "shield should not block anything if it's coverage is 0%"
			await tx.rollbackAsync()

		# shield is not equipped
		await query 'UPDATE items_proto SET coverage = 100'
		await query 'UPDATE items SET equipped = false WHERE id = 10'
		await query 'UPDATE items SET strength = 100'
		for i in [0...5]
			tx = promisifyAll transaction(conn)
			hp = await game._hitAndGetHealth tx, 1, power
			test.strictEqual (await shield tx).strength, 100, 'shield should receive no damage if not equipped'
			test.strictEqual (await greave tx).strength, 0, 'armor should receive all damage if shield is not equipped'
			await tx.rollbackAsync()


exports[NS]._handleDeathInBattle =
	beforeEach: async ->
		await insert 'locations', id: 5, initial: 1
		await insert 'characters', id: 1, health: 0, health_max: 1000, player: 1, exp: 990, level: 1
		await insert 'characters', id: 2, health: 0, health_max: 1000, player: 2, exp: 0, level: 2
		await insert 'characters', id: 11, player: null, level: 3

	'should respawn killed user, restore his health and give some expa to killer': async ->
		await game._handleDeathInBattle conn, 1, 2
		test.strictEqual (await query.val 'SELECT location FROM characters WHERE id=1'), 5,
			'should return user back to initial location'
		test.strictEqual (await query.val 'SELECT health FROM characters WHERE id=1'), 1000,
			"should restore user's health"
		test.strictEqual (await query.val 'SELECT exp FROM characters WHERE id=2'), 0,
			"should not add experience for PK"
		test.strictEqual (await query.val 'SELECT level FROM characters WHERE id=2'), 2,
			"should not add experience for PK"

	'should remove killed monster and give expa to hunter': async ->
		await game._handleDeathInBattle conn, 11, 1
		test.strictEqual +(await query.val 'SELECT count(*) FROM characters'), 2, 'should remove monster'
		test.strictEqual (await query.val 'SELECT exp FROM characters WHERE id=1'), (990 + 50+10) - 1000,
			"should add some experience to monster slayer"
		test.strictEqual (await query.val 'SELECT level FROM characters WHERE id=1'), 2,
			"should account for level-ups"



exports[NS]._hit =
	beforeEach: async ->
		await insert 'characters', id: 1, name: 'SomeUser',    defense: 1, power: 40, health: 5
		await insert 'characters', id: 2, name: 'AnotherUser', defense: 1, power: 50, health: 1000
		await insert 'characters', id: 5, name: 'SomeMonster', defense: 5, power: 20, health: 500
		await insert 'battles', id: 3
		await insert 'battle_participants', battle: 3, character_id: 5, side: 1, index: 1
		await insert 'battle_participants', battle: 3, character_id: 1, side: 0, index: 0
		await insert 'battle_participants', battle: 3, character_id: 2, side: 0, index: 2

		await insert 'characters', id: 3, name: 'FarAwayUser', power: 10, health: 1000
		await insert 'characters', id: 4, name: 'FarAwayMonster', health: 500
		await insert 'battles', id: 8
		await insert 'battle_participants', battle: 8, character_id: 4, side: 1, index: 1
		await insert 'battle_participants', battle: 8, character_id: 3, side: 0, index: 0

	'hitting without equipment': async ->
		# wrong battle
		result = await game._hit conn, 1, 4
		hp = await query.val 'SELECT health FROM characters WHERE id = 4'
		test.strictEqual hp, 500, 'should not do anything if victim is in another battle'
		test.deepEqual result,
				state: 'cancelled'
				reason: 'different battles'
			'should describe premature termination reason'

		# try hit teammate
		result = await game._hit conn, 1, 2
		hp = await query.val 'SELECT health FROM characters WHERE id = 2'
		test.strictEqual hp, 1000, 'should not hit teammate'
		test.deepEqual result,
				state: 'cancelled'
				reason: "can't hit teammate"
			'should describe premature termination reason'

		# wrong hunter
		result = await game._hit conn, 15, 2
		hp = await query.val 'SELECT health FROM characters WHERE id = 2'
		test.strictEqual hp, 1000, 'should not do anything if hunter does not exist'
		test.deepEqual result,
				state: 'cancelled'
				reason: 'hunter not found'
			'should describe premature termination reason'

		# wrong victim
		result = await game._hit conn, 5, 12
		test.deepEqual result,
				state: 'cancelled'
				reason: 'victim not found'
			'should describe premature termination reason'

		# simple DD
		result = await game._hit conn, 1, 5
		hp = await query.val 'SELECT health FROM characters WHERE id = 5'
		test.isBelow hp, 500, 'should deal damage to victim'
		test.deepEqual result,
				state: 'ok'
				victimKilled: false
				battleEnded: false
			'should describe what had happened'

		# knockout one of opponents
		result = await game._hit conn, 5, 1
		rows = await query.all "SELECT * FROM battle_participants WHERE character_id = 1"
		test.strictEqual rows.length, 0, 'should remove participant if one was killed'
		test.deepEqual result,
				state: 'ok'
				victimKilled: true
				battleEnded: false
			'should describe what had happened'

		# defeated all opponents
		await query 'UPDATE characters SET health = 5 WHERE id = 5'
		result = await game._hit conn, 2, 5
		battles = await query.all 'SELECT * FROM battles WHERE id = 3'
		participants = await query.all 'SELECT * FROM battle_participants WHERE battle = 3'
		test.strictEqual battles.length, 0, 'should stop battle if one side won'
		test.strictEqual participants.length, 0, 'should also remove battle participants'
		test.deepEqual result,
				state: 'ok'
				victimKilled: true
				battleEnded: true
			'should describe what had happened'

	'hitting with different weapons': async ->
		['shield', 'weapon-one-handed', 'no-such-item-but-why-not'].forEach (type) ->
			await query 'DELETE FROM items_proto'
			await query 'DELETE FROM items'
			await insert 'items_proto', id:1, name: 'Ogrebator 4000', coverage:100, type: type, damage: 100
			await insert 'items', id:10, prototype:1, owner:1, strength:100, equipped:true

			# normal hit with item
			result = await game._hit conn, 1, 5, 10
			test.strictEqual result.state, 'ok', 'should hit successfully'
			hp = await query.val 'SELECT health FROM characters WHERE id = 5'
			test.ok hp < 500-40, 'should deal more damage than barehanded player can'

			# try hit with 0-damage item
			await query "UPDATE items_proto SET damage = 0"
			result = await game._hit conn, 1, 5, 10
			test.deepEqual result,
					state: 'cancelled'
					reason: "can't hit with this item"
				'should cancel hit and describe reason if item has no dmage gain'

			# try hit with wrong item
			result = await game._hit conn, 1, 5, 123
			test.deepEqual result,
					state: 'cancelled'
					reason: 'weapon item not found'
				'should cancel hit and describe reason if item id is wrong'


exports[NS].hitOpponent =
	beforeEach: async ->
		await insert 'characters', id: 1, name: 'SomeUser', power: 20, defense: 10, health: 1000, player: 1
		await insert 'characters', id: 4, name: 'SomeMonster 1', power: 20, defense: 10, health: 1000
		await insert 'characters', id: 5, name: 'SomeMonster 2', power: 20, defense: 10, health: 1000
		await insert 'battles', id: 3
		await insert 'battle_participants', battle: 3, character_id: 4, side: 1, index: 1
		await insert 'battle_participants', battle: 3, character_id: 5, side: 1, index: 2
		await insert 'battle_participants', battle: 3, character_id: 1, side: 0, index: 0

	'normal attack': async ->
		minDmg = (20-10)/2 * 0.8

		await game.hitOpponent conn, 1, 4
		hp = await query.val 'SELECT health FROM characters WHERE id = 4'
		test.isAtMost hp, 1000-minDmg, 'should hit'
		hp = await query.val 'SELECT health FROM characters WHERE id = 1'
		test.isAtMost hp, 1000-minDmg*2, 'victims should hit back'

		await query 'UPDATE characters SET health=1 WHERE id = 4'
		await query 'UPDATE characters SET health=1000 WHERE id = 1'
		await game.hitOpponent conn, 1, 4
		hp = await query.val 'SELECT health FROM characters WHERE id = 1'
		test.isAtMost hp, 1000-minDmg, 'only alive opponents should hit back'

	'defeating target': async ->
		await query "DELETE FROM battle_participants WHERE character_id = 5"
		await query 'UPDATE characters SET health=1 WHERE id=4'

		await game.hitOpponent conn, 1, 4
		count = + await query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle defeating last opponent'

	'defeated by target': async ->
		await query 'UPDATE characters SET health = 1'
		await game.hitOpponent conn, 1, 4
		count = + await query.val 'SELECT count(*) FROM battles'
		test.strictEqual count, 0, 'should correctly handle when defeated by opponent'


exports[NS].getNearbyUsers =
	beforeEach: async ->
		d = new Date()
		now = (d.getFullYear() + 1) + '-' + (d.getMonth() + 1) + '-' + d.getDate()
		await insert 'uniusers', id: 1, sess_time: now
		await insert 'uniusers', id: 2, sess_time: now
		await insert 'uniusers', id: 3, sess_time: now
		await insert 'uniusers', id: 4, sess_time: '1980-01-01'
		await insert 'uniusers', id: 5, sess_time: now
		await insert 'characters', id: 1, name: 'someuser',  location: 1, player: 1
		await insert 'characters', id: 2, name: 'otheruser', location: 1, player: 2
		await insert 'characters', id: 3, name: 'thirduser', location: 1, player: 3
		await insert 'characters', id: 4, name: 'AFKuser',   location: 1, player: 4
		await insert 'characters', id: 5, name: 'aloneuser', location: 2, player: 5
		await insert 'locations', id: 1

	'should return all online users on this location': async ->
		users = await game.getNearbyUsers conn, 1, 1
		test.deepEqual users, [
			{ id: 2, name: 'otheruser' }
			{ id: 3, name: 'thirduser' }
		]

		users = await game.getNearbyUsers conn, 5, 2
		test.deepEqual users, []


exports[NS].getNearbyMonsters =
	beforeEach: async ->
		await insert 'characters', id: 1, location: 1, player: 1
		await insert 'characters', id: 2, location: 2, player: 2
		await insert 'characters', id: 11, location: 1, attack_chance: 42, name: 'The Creature of Unimaginable Horror'
		await insert 'characters', id: 12, location: 2
		await insert 'characters', id: 13, location: 2

	'should return nearby monsters': async ->
		monsters = await game.getNearbyMonsters conn, 1
		test.strictEqual monsters.length, 1, 'should not return excess monsters'
		test.strictEqual monsters[0].attack_chance, 42, "should return monster's info"
		test.strictEqual monsters[0].name, 'The Creature of Unimaginable Horror', 'should return prototype info too'


exports[NS].isInFight =
	beforeEach: async ->
		await insert 'characters', id: 2
		await insert 'characters', id: 4
		await insert 'battle_participants', character_id: 4

	'should return if user in in fight mode': async ->
		test.isFalse await game.isInFight conn, 2
		test.isTrue await game.isInFight conn, 4


exports[NS].isAutoinvolved =
	beforeEach: async ->
		await insert 'characters', id: 2, autoinvolved_fm: false
		await insert 'characters', id: 4, autoinvolved_fm: true

	'should return if user was attacked or not': async ->
		test.isFalse await game.isAutoinvolved conn, 2
		test.isTrue await game.isAutoinvolved conn, 4


exports[NS].uninvolve =
	beforeEach: async ->
		await insert 'characters', id: 1, autoinvolved_fm: true
		await insert 'battle_participants', character_id: 1

	'should uninvole user': async ->
		await game.uninvolve conn, 1
		test.isFalse await query.val 'SELECT autoinvolved_fm FROM characters WHERE id=1'
		test.isTrue await(game.isInFight conn, 1), 'should not disable fight mode'


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
	beforeEach: async ->
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

		await insert 'characters', this.data

		this.expectedData = Object.clone(this.data)
		this.expectedData.exp_max = 3000
		this.expectedData.fight_mode = false

	'should return character info by id': async ->
		user = await game.getCharacter conn, 1
		test.deepEqual user, this.expectedData

	'should return character info by nickname': async ->
		user = await game.getCharacter conn, 'someuser'
		test.deepEqual user, this.expectedData

	'should return also if character is in fight': async ->
		await insert 'battle_participants', character_id: 1
		this.expectedData.fight_mode = true

		user = await game.getCharacter conn, 1
		test.deepEqual user, this.expectedData

	'should return null if no such user exists': async ->
		test.isNull await game.getCharacter conn, 2
		test.isNull await game.getCharacter conn, 'anotheruser'


exports[NS].getCharacters =
	'should return some characters info': async ->
		await insert 'characters', id: 1, player: 1, name: 'Nagibator', race: 'orc', gender: 'male'
		await insert 'characters', id: 2, player: 1, name: 'Ybivator', race: 'elf', gender: 'female'
		await insert 'characters', id: 3, player: 2, name: 'Voskreshator', race: 'human', gender: 'male'
		chars = await game.getCharacters(conn, 1)
		test.deepEqual chars, [
			{ id: 1, name: 'Nagibator', race: 'orc', gender: 'male' }
			{ id: 2, name: 'Ybivator', race: 'elf', gender: 'female' }
		]

	'should return no characters if user does not have any': async ->
		chars = await game.getCharacters(conn, 1)
		test.deepEqual chars, []


exports[NS].getCharacterItems =
	beforeEach: async ->
		await insert 'items_proto',
			id:1, name:'Magic helmet', type:'helmet', armor_class: 'plate', coverage:50, strength_max:120, damage: 0
		await insert 'items_proto',
			id:2, name:'Speed greaves', type:'greave', armor_class: 'leather', coverage:25, strength_max:110, damage: 10
		await insert 'items_proto',
			id:3, name:'Mighty sword', type:'weapon-one-handed', class:'normal', kind:'sword'
			coverage: null, strength_max:110, damage: 1000
		await insert 'items', id:1, prototype:1, owner:1, strength:100
		await insert 'items', id:2, prototype:2, owner:1, strength:100
		await insert 'items', id:3, prototype:1, owner:2, strength:110
		await insert 'items', id:4, prototype:3, owner:1, strength:110

	"should return properties of character's items": async ->
		items = await game.getCharacterItems conn, 1
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
