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
character = requireCovered __dirname, '../lib/character.coffee'
config = require '../config'
mg = require '../lib/migration'
sync = require 'sync'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
mg = require '../lib/migration'
queryUtils = require '../lib/query_utils'
sugar = require 'sugar'
_conn = null
conn = null
query = null


clearTables = ->
	query 'TRUNCATE ' + [].join.call(arguments, ', ')

insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) VALUES (#{values.map (_,i) -> '$'+(i+1)})", values


exports.setUp = (->
	unless _conn?
		_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
		mg.migrate.sync mg, _conn
	conn = transaction(_conn)
	query = queryUtils.getFor conn
).async()

exports.tearDown = (->
	conn.rollback.sync(conn)
).async()


# warmup: 60ms
exports.characterExists = (test) ->
	exists = (name) -> character.characterExists.sync null, conn, name

	test.strictEqual exists('Sauron'), false, 'should return false if character does not exist'
	insert 'characters', name: 'Sauron'
	test.strictEqual exists('Sauron'), true, 'should return true if character exists'
	test.strictEqual exists('SAURON'), true, 'should ignore capitalization'
	test.strictEqual exists('sauron'), true, 'should ignore capitalization'

	test.done()


exports.createCharacter = (test) ->
	insert 'locations', id: 1, initial: 0
	insert 'locations', id: 2, initial: 1
	insert 'uniusers', id: 1

	console.log '1111'

	try
		console.log '+1111'
		charid = character.createCharacter(conn, 1, 'My First Character', 'elf', 'female')
		console.log '+2222'
		char = query.row "SELECT * FROM characters"
		console.log '+3333'
		user = query.row "SELECT * FROM uniusers"
		console.log '+4444'
	catch ex
		console.log ex.stack

	console.log '2222'

	test.strictEqual user.character_id, charid, "should switch user's character to new character"
	test.strictEqual charid, char.id, 'should return new character id'
	test.strictEqual char.name, 'My First Character', 'should create character with specified name'
	test.strictEqual char.location, 2, 'should create character in initial location'
	test.strictEqual char.race, 'elf', 'should create character with specified race'
	test.strictEqual char.gender, 'female', 'should create character with specified gender'

	console.log '3333'

	ex = null
	try
		character.createCharacter(conn, 1, 'My First Character')
	catch _ex
		ex = _ex
	test.notStrictEqual ex, null, 'should throw exception if such name has been taken'
	test.strictEqual ex.message, 'character already exists',
		'should throw CORRECT exception if such name has been taken'

	console.log '4444'

	energies = [
		['orc', 'male', 220 ]
		['orc', 'female', 200 ]
		['human', 'male', 170 ]
		['human', 'female', 160 ]
		['elf', 'male', 150 ]
		['elf', 'female', 140 ]
	]
	for x in energies
		character.createCharacter(conn, 1, "#{x[0]}-#{x[1]}", x[0], x[1])
		char = query.row 'SELECT * FROM characters WHERE name = $1', [ "#{x[0]}-#{x[1]}" ]
		test.strictEqual char.energy_max, x[2], "should set correct energy_max value for #{x[1]} #{x[0]}"
		test.strictEqual char.energy, x[2], "should set correct energy value for #{x[1]} #{x[0]}"

	console.log '5555'

	test.throws(
		-> character.createCharacter(conn, 1, 'My First Character', 'murloc', 'female')
		Error
		'should not allow weird races'
	)

	console.log '6666'

	test.throws(
		-> character.createCharacter(conn, 1, 'My First Character', 'orc', 'it')
		Error
		'should not allow weird genders'
	)

	console.log '7777'

	query "UPDATE locations SET initial = 1"
	test.throws(
		-> character.createCharacter(conn, null, null)
		Error
		'should throw if something bad happened'
	)

	console.log '8888'

	test.done()


exports.deleteCharacter =
	first: (test) ->
		insert 'characters', id: 1, player: 2
		insert 'characters', id: 2, player: 1
		insert 'characters', id: 3, player: 1
		insert 'characters', id: 4, player: 1
		insert 'characters', id: 5, player: 3
		insert 'uniusers', id: 1, character_id: 2
		[1,2,2,3,4,4].forEach (c) -> insert 'items', owner: c

		itemOwners = -> query.all("SELECT owner FROM items ORDER BY owner").map 'owner'

		# deleting inactive character
		res = character.deleteCharacter conn, 1, 4
		user = query.row "SELECT * FROM uniusers"
		chars = query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if deleted'
		test.deepEqual chars, [{id:2}, {id:3}], 'should delete inactive character'
		test.strictEqual user.character_id, 2, 'should not switch character'
		test.deepEqual itemOwners(), [1,2,2,3], "should delete character's items"

		# deleting current character
		res = character.deleteCharacter conn, 1, 2
		user = query.row "SELECT * FROM uniusers"
		chars = query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if deleted'
		test.deepEqual chars, [{id:3}], 'should delete active character'
		test.strictEqual user.character_id, null, "should clear user's character if deleted was active"
		test.deepEqual itemOwners(), [1,3], "should delete character's items"

		# deleting character of other user
		res = character.deleteCharacter conn, 1, 5
		count = +query.val "SELECT count(*) FROM characters"

		test.strictEqual res.result, 'fail', "should fail if character belongs to other user"
		test.strictEqual res.reason, 'character #5 of user #1 not found',
			'should describe failure if trying to delete in-battle character'
		test.strictEqual count, 3, "should refuse and not delete character if character belongs to other user"
		test.deepEqual itemOwners(), [1,3], "should refuse and not delete items if character belongs to other user"
		test.done()


	second: (test) ->
		# deleting character while in battle
		insert 'characters', id: 1, player: 2
		insert 'uniusers', id: 2, character_id: 3
		insert 'battle_participants', character_id: 1, battle: 5
		insert 'items', owner: 1

		itemOwners = -> query.all("SELECT owner FROM items ORDER BY owner").map 'owner'

		res = character.deleteCharacter conn, 2, 1
		count = +query.val "SELECT count(*) FROM characters"

		test.strictEqual res.result, 'fail', 'should fail if trying to delete in-battle character'
		test.strictEqual res.reason, 'character #1 is in battle #5',
			'should describe failure if trying to delete in-battle character'
		test.strictEqual count, 1, "should refuse and don't delete character if trying to delete in-battle character"
		test.deepEqual itemOwners(), [1], "should refuse and don't delete items if trying to delete in-battle character"

		# FORCE deleting character while in battle
		res = character.deleteCharacter conn, 2, 1, true
		count = +query.val "SELECT count(*) FROM characters"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if force-deleting in-battle character'
		test.strictEqual count, 0, "should delete character if force-deleting in-battle character"
		test.deepEqual itemOwners(), [], "should  delete items if force-deleting in-battle character"
		test.done()


exports.switchCharacter =
	testNoErrors: (test) ->
		insert 'uniusers', id: 1, character_id: 10
		insert 'characters', id: 2, player: 1

		character.switchCharacter(conn, 1, 2)
		charid = query.val "SELECT character_id FROM uniusers"
		test.strictEqual charid, 2, 'should change character_id'
		test.done()

	testErrors: (test) ->
		test.throws(
			-> character.switchCharacter(conn, 1, 2)
			Error
			'should throw if user does not exist'
		)

		insert 'uniusers', id: 1
		insert 'characters', id: 1, player: 1
		test.throws(
			-> character.switchCharacter(conn, 1, 2)
			Error
			'should throw if user does not have such character'
		)
		test.done()
