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


query = (str, values) ->
	conn.query.sync(conn, str, values).rows


queryOne = (str, values) ->
	rows = query(str, values)
	throw new Error('In query:\n' + query + '\nExpected one row, but got ' + rows.length) if rows.length isnt 1
	rows[0]


migrateTables = ->
	args = (i for i in arguments)
	mg.migrate.sync mg, conn, tables: args

insert = (dbName, fields) ->
	params = []
	values = []
	for i of fields
		params.push i
		values.push (if typeof fields[i] is 'string' then "'#{fields[i]}'" else fields[i])
	query "INSERT INTO #{dbName} (#{params.join(', ')}) VALUES (#{values.join(', ')})"


config = require '../config.js'
game = require '../lib/game'
mg = require '../lib/migration'
async = require 'async'
sync = require 'sync'
anyDB = require 'any-db'
conn = null


usedTables = [
	'revision'
	'locations'
	'uniusers'
	'areas'
	'monsters'
	'monster_prototypes'
	'battles'
	'battle_participants'
]

usedCustomTypes = [
	'creature_kind'
	'permission_kind'
]

cleanup = ->
	query 'DROP TABLE IF EXISTS ' + usedTables.join(', ')
	query 'DROP TYPE IF EXISTS ' + usedCustomTypes.join(', ')

exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	cleanup()
).async() # the entrance to the Fieber land

exports.tearDown = (->
	cleanup()
	conn.end()
).async()


exports.getInitialLocation =
	'good test': (test) ->
		migrateTables 'locations'
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

		loc = game.getInitialLocation.sync null, conn
		test.strictEqual loc.id, 2, 'should return id of initial location'
		test.ok loc.ways instanceof Array, 'should return parsed ways from location'
		test.done()

	'bad test': (test) ->
		migrateTables 'locations'
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
		migrateTables 'locations'
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


exports.getUserLocationId =
	testValidData: (test) ->
		migrateTables 'permission_kind', 'uniusers'
		insert 'uniusers', id: 1, 'location': 3

		insert 'uniusers', id: 2, 'location': 1

		id1 = game.getUserLocationId.sync(null, conn, 1)
		id2 = game.getUserLocationId.sync(null, conn, 2)
		test.strictEqual id1, 3, "should return user's location id"
		test.strictEqual id2, 1, "should return user's location id"
		test.done()

	testWrongSessid: (test) ->
		migrateTables 'permission_kind', 'uniusers'
		test.throws(
			-> game.getUserLocationId.sync(null, conn, -1)
			Error
			'should fail on wrong sessid'
		)
		test.done()


exports.getUserLocation =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers', 'locations'
		insert 'uniusers', id: 1, location: 3, sessid: 'someid'
		done()
	
	testValidData: (test) ->
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: 'Left=7|Forward=8|Right=9'
		loc = game.getUserLocation.sync(null, conn, 1)
		
		test.strictEqual loc.id, 3, "should return user's location id"
		test.deepEqual loc.ways, [
				{ target: 7, text: 'Left' }
				{ target: 8, text: 'Forward' }
				{ target: 9, text: 'Right' }
			], 'should return ways from location'
		test.done()
	
	testWrongSessid: (test) ->
		test.throws(
			-> game.getUserLocation.sync null, conn, -1
			Error
			'should fail on wrong id'
		)
		test.done()
	
	testWrongLocid: (test) ->
		insert 'locations', id: 1, area: 5
		
		test.throws(
			-> game.getUserLocation.sync null, conn, 1
			Error
			'should fail if user.location is wrong'
		)
		test.done()


exports.getUserArea =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers', 'locations', 'areas'
		insert 'uniusers', id: 1, location: 3, sessid: 'someid'
		done()
	
	'usual test': (test) ->
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: 'Left=7|Forward=8|Right=9'
		insert 'areas', id: 5, title: 'London'
		area = game.getUserArea.sync null, conn, 1
		
		test.strictEqual area.id, 5, "should return user's area id"
		test.strictEqual area.title, 'London', "should return user's area name"
		test.done()
	
	'wrong user id': (test) ->
		test.throws(
			-> game.getUserArea.sync null, conn, -1
			Error
			'should fail on wrong id'
		)
		test.done()


exports.canChangeLocation = (test) ->
	migrateTables 'permission_kind', 'uniusers', 'locations', 'monsters', 'creature_kind', 'battle_participants'
	insert 'uniusers', id: 1, location: 1
	insert 'locations', id: 1, ways: 'Left=2'
	insert 'locations', id: 2
	
	can = game.canChangeLocation.sync null, conn, 1, 2
	test.strictEqual can, true, "should return true if path exists"
	
	game.changeLocation.sync null, conn, 1, 2
	can = game.canChangeLocation.sync null, conn, 1, 1
	test.strictEqual can, false, "should return false if path doesn't exist"
	test.done()


exports.changeLocation =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers',
			'locations', 'monsters', 'battles',
			'creature_kind', 'battle_participants'
		insert 'uniusers', id: 1, location: 1, initiative: 50
		insert 'locations', id: 1, ways: 'Left=2'
		insert 'locations', id: 2
		done()
	
	'with peaceful monster': (test) ->
		insert 'monsters', id: 1, location: 2, attack_chance: -1
		game.changeLocation.sync null, conn, 1, 2
		
		locid = game.getUserLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user shold have moved to new location'
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacked'
		test.done()
	
	'with angry monster': (test) ->
		insert 'monsters', id: 1, location: 2, attack_chance: 100, initiative: 100
		insert 'monsters', id: 2, location: 2, attack_chance: 100, initiative: 5
		insert 'monsters', id: 3, location: 2, attack_chance: -1, initiative: 10
		game.changeLocation.sync null, conn, 1, 2
		
		locid = game.getUserLocationId.sync(null, conn, 1)
		test.strictEqual locid, 2, 'user shold have moved to new location'
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, true, 'user should be attacked'
		
		battles = query('SELECT * FROM battles')
		test.strictEqual battles.length, 1, 'one battle should appear'
		
		participants = query('SELECT battle, id, kind, index FROM battle_participants ORDER BY index')
		test.deepEqual participants, [
			{ battle: 1, id: 1, kind: 'monster', index: 0 }
			{ battle: 1, id: 1, kind: 'user',    index: 1 }
			{ battle: 1, id: 3, kind: 'monster', index: 2 }
			{ battle: 1, id: 2, kind: 'monster', index: 3 }
		], 'they all should have been envolved in right order'
		
		userSide = queryOne("SELECT side FROM battle_participants WHERE kind='user' AND id=1").side
		query("SELECT side FROM battle_participants WHERE kind='monster'").forEach (m) ->
			test.ok userSide isnt m.side, 'user and monsters should be on different sides'
		test.done()
	
	'with busy monster': (test) ->
		insert 'monsters', id: 1, location: 2, attack_chance: 100, initiative: 100
		insert 'battle_participants', id: 1, kind: 'monster'
		game.changeLocation.sync null, conn, 1, 2
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacked'
		test.done()


exports.goAttack =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers', 'monsters', 'battles', 'creature_kind', 'battle_participants'
		insert 'uniusers', id: 1, location: 1, initiative: 10
		done()
	
	'usual test': (test) ->
		insert 'monsters', id: 1, location: 1, initiative: 20
		insert 'monsters', id: 2, location: 1, initiative: 30
		game.goAttack.sync null, conn, 1
		
		envolvedMonstersCount = +queryOne("SELECT count(*) FROM battle_participants WHERE kind='monster'").count
		test.strictEqual envolvedMonstersCount, 2, 'all monsters should have been envolved'
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, true, 'user should be attacking'
		test.done()
	
	'on empty location': (test) ->
		game.goAttack.sync null, conn, 1
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be fighting'
		
		test.strictEqual query('SELECT id FROM battles').length, 0, 'should be no battles'
		test.strictEqual query('SELECT id FROM battle_participants').length, 0, 'should be no participants'
		test.done()


exports.goEscape =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers', 'battles', 'creature_kind', 'battle_participants'
		insert 'uniusers', id: 1, autoinvolved_fm: 1
		insert 'battles', id: 3
		insert 'battle_participants', battle: 3, id: 1, kind: 'user'
		insert 'battle_participants', battle: 3, id: 1, kind: 'monster'
		done()
	
	test: (test) ->
		game.goEscape.sync null, conn, 1
		
		fm = game.isInFight.sync(null, conn, 1)
		test.strictEqual fm, false, 'user should not be attacking'
		
		autoinvolved = queryOne('SELECT autoinvolved_fm FROM uniusers WHERE id=1').autoinvolved_fm
		test.strictEqual autoinvolved, 0, 'user should not be autoinvolved'
		
		battles = query('SELECT * FROM battles')
		test.strictEqual battles.length, 0, 'battle should be over and destroyed'
		
		participants = query('SELECT id FROM battle_participants')
		test.strictEqual participants.length, 0, 'all participants should have been removed'
		test.done()


exports.getBattleParticipants =
	setUp: (done) ->
		migrateTables 'permission_kind', 'uniusers',
			'monsters', 'monster_prototypes',
			'creature_kind', 'battle_participants'
		insert 'uniusers', id: 1, username: 'SomeUser'
		insert 'monster_prototypes', id: 2, name: 'SomeMonster'
		insert 'monsters', id: 4, prototype: 2
		insert 'monsters', id: 5, prototype: 2
		insert 'battle_participants', battle: 3, id: 1, kind: 'user', side: 1, index: 1
		insert 'battle_participants', battle: 3, id: 4, kind: 'monster', side: 0, index: 0
		insert 'battle_participants', battle: 3, id: 5, kind: 'monster', side: 0, index: 2
		done()
	
	test: (test) ->
		participants = game.getBattleParticipants.sync(null, conn, 1)
		test.deepEqual participants, [
			{ id: 4, kind: 'monster', name: 'SomeMonster', side: 0, index: 0 }
			{ id: 1, kind: 'user', name: 'SomeUser', side: 1, index: 1 }
			{ id: 5, kind: 'monster', name: 'SomeMonster', side: 0, index: 2 }
		], 'should return participants with names'
		test.done()
	
	'wrong kind': (test) ->
		query "ALTER TYPE creature_kind ADD VALUE 'very new kind' AFTER 'monster'"
		insert 'battle_participants', battle: 3, id: 5, kind: 'very new kind', side: 0, index: 2
		
		test.throws(
			-> game.getBattleParticipants.sync null, conn, 1
			Error
			'should throw error'
		)
		test.done()


exports.getNearbyUsers =
	setUp: (done) ->
		d = new Date()
		now = (d.getFullYear() + 1) + '-' + (d.getMonth() + 1) + '-' + d.getDate()
		migrateTables 'permission_kind', 'uniusers', 'locations'
		insert 'uniusers', id: 1, username: 'someuser',  location: 1, sess_time: now
		insert 'uniusers', id: 2, username: 'otheruser', location: 1, sess_time: now
		insert 'uniusers', id: 3, username: 'thirduser', location: 1, sess_time: now
		insert 'uniusers', id: 4, username: 'AFKuser',   location: 1, sess_time: '1980-01-01'
		insert 'uniusers', id: 5, username: 'aloneuser', location: 2, sess_time: now
		insert 'locations', id: 1
		done()
	
	testValidData: (test) ->
		users = game.getNearbyUsers.sync null, conn, 1, 1
		test.deepEqual users, [
			{ id: 2, username: 'otheruser' }
			{ id: 3, username: 'thirduser' }
		], 'should return all online users on this location'
		
		users = game.getNearbyUsers.sync null, conn, 5, 2
		test.deepEqual users, [], 'alone user should be alone. for now'
		test.done()


exports.getNearbyMonsters = (test) ->
	migrateTables 'permission_kind', 'uniusers', 'monster_prototypes', 'monsters'
	insert 'uniusers', id: 1, location: 1
	insert 'uniusers', id: 2, location: 2
	insert 'monster_prototypes', id: 1, name: 'The Creature of Unimaginable Horror'
	insert 'monsters', id: 1, prototype: 1, location: 1, attack_chance: 42
	insert 'monsters', id: 2, prototype: 1, location: 2
	insert 'monsters', id: 3, prototype: 1, location: 2
	monsters = game.getNearbyMonsters.sync null, conn, 1
	
	test.strictEqual monsters.length, 1, 'should not return excess monsters'
	test.strictEqual monsters[0].attack_chance, 42, "should return monster's info"
	test.strictEqual monsters[0].name, 'The Creature of Unimaginable Horror', 'should return prototype info too'
	test.done()


exports.isInFight = (test) ->
	migrateTables 'permission_kind', 'uniusers', 'creature_kind', 'battle_participants'
	insert 'uniusers', id: 2
	insert 'uniusers', id: 4
	insert 'battle_participants', kind: 'user', id: 4
	
	isIn = game.isInFight.sync null, conn, 2
	test.strictEqual isIn, false, 'should return false if user is not in fight mode'
	
	isIn = game.isInFight.sync null, conn, 4
	test.strictEqual isIn, true, 'should return true if user is in fight mode'
	test.done()


exports.isAutoinvolved = (test) ->
	migrateTables 'permission_kind', 'uniusers'
	insert 'uniusers', id: 2, autoinvolved_fm: 0
	insert 'uniusers', id: 4, autoinvolved_fm: 1
	
	autoinv = game.isAutoinvolved.sync null, conn, 2
	test.strictEqual autoinv, false, 'should return false if user was not attacked'
	
	autoinv = game.isAutoinvolved.sync null, conn, 4
	test.strictEqual autoinv, true, 'should return true if user was attacked'
	test.done()

exports.uninvolve = (test) ->
	migrateTables 'permission_kind', 'uniusers', 'creature_kind', 'battle_participants'
	insert 'uniusers', id: 1, autoinvolved_fm: 1
	insert 'battle_participants', kind: 'user', id: 1
	game.uninvolve.sync null, conn, 1
	
	isInFight = game.isInFight.sync null, conn, 1
	test.strictEqual isInFight, true, 'should not disable fight mode'
	
	autoinvolved = queryOne('SELECT autoinvolved_fm FROM uniusers WHERE id=1').autoinvolved_fm
	test.strictEqual autoinvolved, 0, 'user should not be autoinvolved'
	test.done()


exports.getUserCharacters =
	testNoErrors: (test) ->
		migrateTables 'permission_kind', 'uniusers'
		insert 'uniusers',
			id: 1
			username: 'someuser'
			autoinvolved_fm: 1
			health: 100
			health_max: 200
			mana: 50
			mana_max: 200
			exp: 1000
			level: 2
			energy: 128
			power: 1
			defense: 2
			agility: 3
			accuracy: 4
			intelligence: 5
			initiative: 6
		
		expectedData =
			id: 1
			username: 'someuser'
			health: 100
			health_max: 200
			health_percent: 50
			mana: 50
			mana_max: 200
			mana_percent: 25
			level: 2
			exp: 1000
			exp_max: 3000
			exp_percent: 0
			energy: 128
			power: 1
			defense: 2
			agility: 3
			accuracy: 4
			intelligence: 5
			initiative: 6
		
		user = game.getUserCharacters.sync null, conn, 1
		test.deepEqual user, expectedData, 'should return specific fields by id'
		user = game.getUserCharacters.sync null, conn, 'someuser'
		test.deepEqual user, expectedData, 'should return specific fields by nickname'
		
		user = game.getUserCharacters.sync null, conn, 2
		test.strictEqual user, null, 'should return null if no such user exists'
		user = game.getUserCharacters.sync null, conn, 'anotheruser'
		test.strictEqual user, null, 'should return null if no such user exists'
		test.done()
	
	testErrors: (test) ->
		test.throws(
			-> game.getUserCharacters.sync conn, 1
			Error
			''
		)
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