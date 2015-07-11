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
		conn = anyDB.createConnection(config.DATABASE_URL_TEST)
		query = queryUtils.getFor conn
		mg.migrate.sync mg, conn
).async() # the entrance to the Fieber land

#exports.tearDown = (->).async()


exports.characterExists = (test) ->
	exists = (name) ->
		character.characterExists.sync null, conn, name

	clearTables 'characters'
	insert 'characters', name: 'Sauron'

	test.strictEqual exists('Sauron'), true, 'should return true if character exists'
	test.strictEqual exists('SAURON'), true, 'should ignore capitalization'
	test.strictEqual exists('sauron'), true, 'should ignore capitalization'

	query 'TRUNCATE characters'
	test.strictEqual exists('Sauron'), false, 'should return false if character does not exist'
	test.done()


exports.createCharacter = (test) ->
	clearTables 'uniusers', 'characters', 'locations'
	insert 'locations', id: 1, initial: 0
	insert 'locations', id: 2, initial: 1
	insert 'uniusers', id: 1

	charid = character.createCharacter(conn, 1, 'My First Character')
	char = query.row "SELECT * FROM characters"
	user = query.row "SELECT * FROM uniusers"

	test.strictEqual user.character_id, charid, "should switch user's character to new character"
	test.strictEqual charid, char.id, 'should return new character id'
	test.strictEqual char.name, 'My First Character', 'should create character with specified name'
	test.strictEqual char.location, 2, 'should create character in initial location'

	ex = null
	try
		character.createCharacter(conn, 1, 'My First Character')
	catch _ex
		ex = _ex
	test.notStrictEqual ex, null, 'should throw exception if such name has been taken'
	test.strictEqual ex.message, 'character already exists',
		'should throw CORRECT exception if such name has been taken'

	query "UPDATE locations SET initial = 1"
	test.throws(
		-> character.createCharacter(conn, null, null)
		Error
		'should throw if something bad happened'
	)
	test.done()


exports.deleteCharacter = (test) ->
	clearTables 'uniusers', 'characters', 'items', 'items_proto', 'battle_participants', 'battles'
	insert 'characters', id: 1, player: 2
	insert 'characters', id: 2, player: 1
	insert 'characters', id: 3, player: 1
	insert 'characters', id: 4, player: 1
	insert 'characters', id: 5, player: 3
	insert 'uniusers', id: 1, character_id: 2
	[1,2,2,3,4,4].forEach (c) -> insert 'items', owner: c

	itemOwners = -> query.all("SELECT owner FROM items ORDER BY owner").map 'owner'

	# deleting inactive character
	ok = character.deleteCharacter conn, 1, 4
	user = query.row "SELECT * FROM uniusers"
	chars = query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

	test.strictEqual ok, true, 'should return true if deleted'
	test.deepEqual chars, [{id:2}, {id:3}], 'should delete inactive character'
	test.strictEqual user.character_id, 2, 'should not switch character'
	test.deepEqual itemOwners(), [1,2,2,3], "should delete character's items"

	# deleting current character
	ok = character.deleteCharacter conn, 1, 2
	user = query.row "SELECT * FROM uniusers"
	chars = query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

	test.strictEqual ok, true, 'should return true if deleted'
	test.deepEqual chars, [{id:3}], 'should delete active character'
	test.strictEqual user.character_id, null, "should clear user's character if deleted was active"
	test.deepEqual itemOwners(), [1,3], "should delete character's items"

	# deleting character of other user
	ok = character.deleteCharacter conn, 1, 5
	count = +query.val "SELECT count(*) FROM characters"

	test.strictEqual ok, false, "should return false if trying to delete character of other user"
	test.strictEqual count, 3, 'should not delete character'
	test.deepEqual itemOwners(), [1,3], "should not delete items"

	# deleting character while in battle
	clearTables 'uniusers', 'characters', 'battle_participants', 'items'
	insert 'characters', id: 1, player: 2
	insert 'uniusers', id: 2, character_id: 3
	insert 'battle_participants', character_id: 1
	insert 'items', owner: 1

	ok = character.deleteCharacter conn, 2, 1
	count = +query.val "SELECT count(*) FROM characters"

	test.strictEqual ok, false, 'should return false if trying to delete in-battle character'
	test.strictEqual count, 1, 'should not delete character'
	test.deepEqual itemOwners(), [1], "should not delete items"
	test.done()


exports.switchCharacter =
	testNoErrors: (test) ->
		clearTables 'uniusers', 'characters'
		insert 'uniusers', id: 1, character_id: 10
		insert 'characters', id: 2, player: 1

		character.switchCharacter(conn, 1, 2)
		charid = query.val "SELECT character_id FROM uniusers"
		test.strictEqual charid, 2, 'should change character_id'
		test.done()

	testErrors: (test) ->
		clearTables 'uniusers', 'characters'
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
