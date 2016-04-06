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

NS = 'character'; exports[NS] = {}  # namespace
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
sugar = require 'sugar'

mg = require '../lib/migration.coffee'
queryUtils = require '../lib/query_utils.coffee'

character = requireCovered __dirname, '../lib/character.coffee'

_conn = null
conn = null
query = null


insert = (table, fields) ->
	queryUtils.unsafeInsert conn, table, fields


exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	mg.migrate.sync mg, _conn

exports[NS].beforeEach = t ->
	conn = transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = t ->
	conn.rollback.sync(conn)


exports[NS].characterExists =
	'should check if a character with the given name exists': t ->
		exists = (name) -> character.characterExists.sync null, conn, name

		test.isFalse exists('Sauron'), 'should return false if character does not exist'
		insert 'characters', name: 'Sauron'
		test.isTrue exists('Sauron'), 'should return true if character exists'
		test.isTrue exists('SAURON'), 'should ignore capitalization'
		test.isTrue exists('sauron'), 'should ignore capitalization'


exports[NS].createCharacter =
	'should create characters': t ->
		insert 'locations', id: 1, initial: 0
		insert 'locations', id: 2, initial: 1
		insert 'uniusers', id: 1

		charid = character.createCharacter(conn, 1, 'My First Character', 'elf', 'female')
		char = query.row "SELECT * FROM characters"
		user = query.row "SELECT * FROM uniusers"

		test.strictEqual user.character_id, charid, "should switch user's character to new character"
		test.strictEqual charid, char.id, 'should return new character id'
		test.strictEqual char.name, 'My First Character', 'should create character with specified name'
		test.strictEqual char.location, 2, 'should create character in initial location'
		test.strictEqual char.race, 'elf', 'should create character with specified race'
		test.strictEqual char.gender, 'female', 'should create character with specified gender'

		test.throws(
			-> character.createCharacter(conn, 1, 'My First Character')
			Error, 'character already exists'
			'should throw correct exception if such name has been taken'
		)

		[
			['orc', 'male', 220 ]
			['orc', 'female', 200 ]
			['human', 'male', 170 ]
			['human', 'female', 160 ]
			['elf', 'male', 150 ]
			['elf', 'female', 140 ]
		].forEach ([race, gender, energy]) ->
			character.createCharacter(conn, 1, "#{race}-#{gender}", race, gender)
			char = query.row 'SELECT * FROM characters WHERE name = $1', [ "#{race}-#{gender}" ]
			test.strictEqual char.energy_max, energy, "should set correct energy_max value for #{gender} #{race}"
			test.strictEqual char.energy, energy, "should set correct energy value for #{gender} #{race}"

	'should not allow weird races': t ->
		test.throws ->
			character.createCharacter(conn, 1, 'My First Character', 'murloc', 'female')

	'should not allow weird genders': t ->
		test.throws ->
			character.createCharacter(conn, 1, 'My First Character', 'orc', 'it')

	'should throw if something bad happened': t ->
		insert 'locations', id: 1, initial: 1
		insert 'locations', id: 2, initial: 1
		test.throws ->
			character.createCharacter(conn, null, null)


exports[NS].deleteCharacter =
	'should delete characters': t ->
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
		test.isNull user.character_id, "should clear user's character if deleted was active"
		test.deepEqual itemOwners(), [1,3], "should delete character's items"

		# deleting character of other user
		res = character.deleteCharacter conn, 1, 5
		count = +query.val "SELECT count(*) FROM characters"

		test.strictEqual res.result, 'fail', "should fail if character belongs to other user"
		test.strictEqual res.reason, 'character #5 of user #1 not found',
			'should describe failure if trying to delete in-battle character'
		test.strictEqual count, 3, "should refuse and not delete character if character belongs to other user"
		test.deepEqual itemOwners(), [1,3], "should refuse and not delete items if character belongs to other user"


	'should correctly process battle states': t ->
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


exports[NS].switchCharacter =
	'should switch active character': t ->
		insert 'uniusers', id: 1, character_id: 10
		insert 'characters', id: 2, player: 1

		character.switchCharacter(conn, 1, 2)
		charid = query.val "SELECT character_id FROM uniusers"
		test.strictEqual charid, 2, 'should change character_id'

	'should throw if user does not exist': t ->
		test.throws ->
			character.switchCharacter(conn, 1, 2)

	'should throw if user does not have such character': t ->
		insert 'uniusers', id: 1
		insert 'characters', id: 1, player: 1
		test.throws ->
			character.switchCharacter(conn, 1, 2)