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

NS = 'migration'; exports[NS] = {}  # namespace
{test, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll
queryUtils = require '../lib/query_utils'
tables = require '../lib/tables'

migration = requireCovered __dirname, '../lib/migration.coffee'

_conn = null
conn = null
query = null


migrationData = [
	[
		[ 'test_table', 'create', 'id INT' ]
		[ 'other_table', 'create', 'id INT' ]
	]
	[
		[ 'test_table', 'addCol', 'col0 BOX' ]
		[ 'test_table', 'addCol', 'col1 MACADDR' ]
	]
	[
		[ 'test_table', 'addCol', 'col3 INT' ]
		[ 'test_table', 'changeCol', 'col3', 'BIGINT' ]
		[ 'test_table', 'renameCol', 'col3', 'col2' ]
		[ 'other_table', 'addCol', 'col0 LSEG' ]
	]
	[
		[ 'test_table', 'addCol', 'col3 MONEY' ]
		[ 'test_table', 'dropCol', 'col3' ]
	]
]


# if this won't crash, everything should be OK
migrationDataBackup = []


exports[NS].before = ->
	_conn = promisifyAll anyDB.createConnection(config.DATABASE_URL_TEST)

exports[NS].beforeEach = async ->
	conn = promisifyAll transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn
	migrationDataBackup = migration.getMigrationsData()
	await query 'DROP TABLE IF EXISTS revision'
	migration.setMigrationsData migrationData

exports[NS].afterEach = ->
	migration.setMigrationsData migrationDataBackup
	conn.rollbackAsync()



exports[NS].getCurrentRevision =
	'should return current revision number': async ->
		await query 'CREATE TABLE revision (revision INT)'
		await query 'INSERT INTO revision VALUES (945)'
		rev = await migration.getCurrentRevision conn
		test.strictEqual rev, 945

	'should return -1 if revision table is not created': async ->
		rev = await migration.getCurrentRevision conn
		test.strictEqual rev, -1

	'should fail on connection errors': async ->
		fakeConn =
			queryAsync: async (text, args) ->
				throw new Error('THE_VERY_STRANGE_ERROR')
		await test.isRejected migration.getCurrentRevision(fakeConn), /THE_VERY_STRANGE_ERROR/


exports[NS].setRevision =
	'should create revision table if it does not exist': async ->
		await migration.setRevision conn, 1
		test.isTrue await tables.tableExists conn, 'revision'

	'should set correct revision number': async ->
		await migration.setRevision conn, 1
		test.strictEqual (await migration.getCurrentRevision conn), 1

		await migration.setRevision conn, 2
		test.strictEqual (await migration.getCurrentRevision conn), 2


exports[NS]._justMigrate =
	'should correctly perform specified migration': async ->
		await migration._justMigrate conn, 0
		tt = await query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		ot = await query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"

		test.deepEqual [tt, ot], [
				[{column_name: 'id'}]
				[{column_name: 'id'}]
			], 'should correctly perform first migration'

		await migration._justMigrate conn, 1
		tt = await query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		ot = await query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"

		test.deepEqual [tt, ot], [
				[{column_name: 'col0'}, {column_name: 'col1'}, {column_name: 'id'}]
				[{column_name: 'id'}]
			], 'should correctly add second migration'

	'should perform raw SQL commands': async ->
		migration.setMigrationsData [[
			[ 'test_table', 'create', 'id INT' ]
			[ 'test_table', 'rawsql', 'INSERT INTO test_table (id) VALUES (1), (2), (5)' ]
		]]
		await migration._justMigrate conn, 0

		rows = await query.all 'SELECT * FROM test_table'
		test.deepEqual rows, [
			{id: 1}, {id: 2}, {id: 5}
		]

	'should return error if failed to migrate': async ->
		await query 'DROP TABLE IF EXISTS test_table'
		await migration.setRevision conn, 0

		await test.isRejectedWithPgError(
			migration._justMigrate conn, 1
			'42P01'  # relation "test_table" does not exist
		)


exports[NS].migrate =
	'should perform some or all migratons': async ->
		await migration.migrate conn, { dest_revision: 1 }

		rows = await query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.deepEqual rows, [
			{ column_name: 'col0', data_type: 'box' }
			{ column_name: 'col1', data_type: 'macaddr' }
			{ column_name: 'id', data_type: 'integer' }
		], 'should correctly perform part of migrations'

		orows = await query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.deepEqual orows, [
			{ column_name: 'id', data_type: 'integer' }
		], 'should correctly perform part of migrations'

		revision = await migration.getCurrentRevision conn
		test.strictEqual revision, 1, 'should set correct revision'


		await migration.migrate conn

		rows = await query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.deepEqual rows, [
			{ column_name: 'col0', data_type: 'box' }
			{ column_name: 'col1', data_type: 'macaddr' }
			{ column_name: 'col2', data_type: 'bigint' }
			{ column_name: 'id', data_type: 'integer' }
		], 'should correctly perform all remaining migrations'

		orows = await query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.deepEqual orows, [
			{ column_name: 'col0', data_type: 'lseg' }
			{ column_name: 'id', data_type: 'integer' }
		], 'should correctly perform all remaining migrations'

		revision = await migration.getCurrentRevision conn
		test.strictEqual revision, 3, 'should set correct revision'

	'should be able to migrate just one table': async ->
		rev0 = await migration.getCurrentRevision conn
		await migration.migrate conn, {dest_revision: 0, table: 'test_table'}
		rev1 = await migration.getCurrentRevision conn
		test.strictEqual rev0, rev1, 'should not change version for one table'

		row = await query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		exists = await tables.tableExists conn, 'other_table'

		test.deepEqual row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified table'
		test.ok not exists, 'migration for other tables should not have been performed'

	'should be able to migrate several tables': async ->
		rev0 = await migration.getCurrentRevision conn
		await migration.migrate conn,
			{ dest_revision: 0, tables: ['no_such_table', 'test_table', 'other_table'] }
		rev1 = await migration.getCurrentRevision conn
		test.strictEqual rev0, rev1, 'should not change version'

		row = await query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.deepEqual row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified tables'

		row = await query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.ok row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified tables'

	'should migrate verbosely if flag is set': async ->
		testLog = async (message, promise) ->
			_log = console.log
			_write = process.stdout.write
			log_times = 0
			console.log = (x) -> log_times++
			process.stdout.write = (x) -> log_times++
			await promise
			console.log = _log
			process.stdout.write = _write
			test.isAbove log_times, 0, message

		await testLog 'should say something',
			migration.migrate conn, {verbose: true}

		await testLog 'should say something (when all migrations already completed)',
			migration.migrate conn, {verbose: true}
