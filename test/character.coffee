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
{test, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll
sugar = require 'sugar'

mg = require '../lib/migration.coffee'
queryUtils = require '../lib/query_utils.coffee'

character = requireCovered __dirname, '../lib/character.coffee'

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

exports[NS].afterEach = ->
	conn.rollbackAsync()


exports[NS].characterExists =
	'should check if a character with the given name exists': async ->
		exists = (name) -> character.characterExists conn, name

		test.isFalse await(exists 'Sauron'), 'should return false if character does not exist'
		await insert 'characters', name: 'Sauron'
		test.isTrue await(exists 'Sauron'), 'should return true if character exists'
		test.isTrue await(exists 'SAURON'), 'should ignore capitalization'
		test.isTrue await(exists 'sauron'), 'should ignore capitalization'


exports[NS].createCharacter =
	'should create characters': async ->
		await insert 'locations', id: 1, initial: 0
		await insert 'locations', id: 2, initial: 1
		await insert 'uniusers', id: 1

		charid = await character.createCharacter(conn, 1, 'My First Character', 'elf', 'female')
		char = await query.row "SELECT * FROM characters"
		user = await query.row "SELECT * FROM uniusers"

		test.strictEqual user.character_id, charid, "should switch user's character to new character"
		test.strictEqual charid, char.id, 'should return new character id'
		test.strictEqual char.name, 'My First Character', 'should create character with specified name'
		test.strictEqual char.location, 2, 'should create character in initial location'
		test.strictEqual char.race, 'elf', 'should create character with specified race'
		test.strictEqual char.gender, 'female', 'should create character with specified gender'

		test.throws(
			-> await character.createCharacter(conn, 1, 'My First Character')
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
			await character.createCharacter(conn, 1, "#{race}-#{gender}", race, gender)
			char = await query.row 'SELECT * FROM characters WHERE name = $1', [ "#{race}-#{gender}" ]
			test.strictEqual char.energy_max, energy, "should set correct energy_max value for #{gender} #{race}"
			test.strictEqual char.energy, energy, "should set correct energy value for #{gender} #{race}"

	'should not allow weird races': async ->
		test.throwsPgError(
			-> await character.createCharacter(conn, 1, 'My First Character', 'murloc', 'female')
			'22P02'  # invalid input value for enum uonline_race: "murloc"
		)

	'should not allow weird genders': async ->
		test.throwsPgError(
			-> await character.createCharacter(conn, 1, 'My First Character', 'orc', 'it')
			'22P02'  # invalid input value for enum uonline_gender: "it"
		)

	'should throw if something bad happened': async ->
		await insert 'locations', id: 1, initial: 1
		await insert 'locations', id: 2, initial: 1
		test.throwsPgError(
			-> await character.createCharacter(conn, null, null)
			'21000'  # more than one row returned by a subquery used as an expression
		)


exports[NS].deleteCharacter =
	'should delete characters': async ->
		await insert 'characters', id: 1, player: 2
		await insert 'characters', id: 2, player: 1
		await insert 'characters', id: 3, player: 1
		await insert 'characters', id: 4, player: 1
		await insert 'characters', id: 5, player: 3
		await insert 'uniusers', id: 1, character_id: 2
		for cid in [1,2,2,3,4,4]
			await insert 'items', owner: cid

		itemOwners = async -> await(query.all("SELECT owner FROM items ORDER BY owner")).map 'owner'

		# deleting inactive character
		res = await character.deleteCharacter conn, 1, 4
		user = await query.row "SELECT * FROM uniusers"
		chars = await query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if deleted'
		test.deepEqual chars, [{id:2}, {id:3}], 'should delete inactive character'
		test.strictEqual user.character_id, 2, 'should not switch character'
		test.deepEqual await(itemOwners()), [1,2,2,3], "should delete character's items"

		# deleting current character
		res = await character.deleteCharacter conn, 1, 2
		user = await query.row "SELECT * FROM uniusers"
		chars = await query.all "SELECT id FROM characters WHERE player = 1 ORDER BY id"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if deleted'
		test.deepEqual chars, [{id:3}], 'should delete active character'
		test.isNull user.character_id, "should clear user's character if deleted was active"
		test.deepEqual await(itemOwners()), [1,3], "should delete character's items"

		# deleting character of other user
		res = await character.deleteCharacter conn, 1, 5
		count = + await query.val "SELECT count(*) FROM characters"

		test.strictEqual res.result, 'fail', "should fail if character belongs to other user"
		test.strictEqual res.reason, 'character #5 of user #1 not found',
			'should describe failure if trying to delete in-battle character'
		test.strictEqual count, 3, "should refuse and not delete character if character belongs to other user"
		test.deepEqual await(itemOwners()), [1,3], "should refuse and not delete items if character belongs to other user"


	'should correctly process battle states': async ->
		# deleting character while in battle
		await insert 'characters', id: 1, player: 2
		await insert 'uniusers', id: 2, character_id: 3
		await insert 'battle_participants', character_id: 1, battle: 5
		await insert 'items', owner: 1

		itemOwners = async -> await(query.all("SELECT owner FROM items ORDER BY owner")).map 'owner'

		res = await character.deleteCharacter conn, 2, 1
		count = + await query.val "SELECT count(*) FROM characters"

		test.strictEqual res.result, 'fail', 'should fail if trying to delete in-battle character'
		test.strictEqual res.reason, 'character #1 is in battle #5',
			'should describe failure if trying to delete in-battle character'
		test.strictEqual count, 1, "should refuse and don't delete character if trying to delete in-battle character"
		test.deepEqual await(itemOwners()), [1], "should refuse and don't delete items if trying to delete in-battle character"

		# FORCE deleting character while in battle
		res = await character.deleteCharacter conn, 2, 1, true
		count = + await query.val "SELECT count(*) FROM characters"

		test.deepEqual res, {result: 'ok'}, 'should return "ok" if force-deleting in-battle character'
		test.strictEqual count, 0, "should delete character if force-deleting in-battle character"
		test.deepEqual await(itemOwners()), [], "should  delete items if force-deleting in-battle character"


exports[NS].switchCharacter =
	'should switch active character': async ->
		await insert 'uniusers', id: 1, character_id: 10
		await insert 'characters', id: 2, player: 1

		await character.switchCharacter(conn, 1, 2)
		charid = await query.val "SELECT character_id FROM uniusers"
		test.strictEqual charid, 2, 'should change character_id'

	'should throw if user does not exist': async ->
		test.throws(
			-> await character.switchCharacter(conn, 1, 2)
			Error, "user #1 doesn't have character #2"
		)

	'should throw if user does not have such character': async ->
		await insert 'uniusers', id: 1
		await insert 'characters', id: 1, player: 1
		test.throws(
			-> await character.switchCharacter(conn, 1, 2)
			Error, "user #1 doesn't have character #2"
		)
