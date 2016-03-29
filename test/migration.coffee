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
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
mg = require '../lib/migration'
queryUtils = require '../lib/query_utils'
tables = require '../lib/tables'

game = requireCovered __dirname, '../lib/migration.coffee'

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


exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	mg.migrate.sync mg, _conn

exports[NS].beforeEach = t ->
	conn = transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn
	migrationDataBackup = mg.getMigrationsData()
	query 'DROP TABLE IF EXISTS revision'
	mg.setMigrationsData migrationData

exports[NS].afterEach = t ->
	mg.setMigrationsData migrationDataBackup
	conn.rollback.sync(conn)



exports[NS].getCurrentRevision =
	'should return current revision number': t ->
		query 'CREATE TABLE revision (revision INT)'
		query 'INSERT INTO revision VALUES (945)'
		rev = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev, 945

	'should return -1 if revision table is not created': t ->
		rev = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev, -1

	'should fail on exceptions': t ->
		test.throws(
			-> mg.getCurrentRevision.sync null, 'nonsense'
			Error, 'dbConnection.query is not a function'
		)

	'should fail on connection errors': t ->
		fakeConn =
			query: (text, args, callback) ->
				callback new Error('THE_VERY_STRANGE_ERROR')
		test.throws(
			-> mg.getCurrentRevision.sync null, fakeConn
			Error, 'THE_VERY_STRANGE_ERROR'
		)


exports[NS].setRevision =
	'should crete revision table if it does not exist': t ->
		mg.setRevision.sync null, conn, 1
		test.isTrue tables.tableExists.sync(null, conn, 'revision')

	'should set correct revision number': t ->
		mg.setRevision.sync null, conn, 1
		test.strictEqual mg.getCurrentRevision.sync(null, conn), 1

		mg.setRevision.sync null, conn, 2
		test.strictEqual mg.getCurrentRevision.sync(null, conn), 2


exports[NS]._justMigrate =
	'should correctly perform specified migration': t ->
		mg._justMigrate conn, 0
		tt = query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		ot = query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"

		test.deepEqual [tt, ot], [
				[{column_name: 'id'}]
				[{column_name: 'id'}]
			], 'should correctly perform first migration'

		mg._justMigrate conn, 1
		tt = query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		ot = query.all 'SELECT column_name FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"

		test.deepEqual [tt, ot], [
				[{column_name: 'col0'}, {column_name: 'col1'}, {column_name: 'id'}]
				[{column_name: 'id'}]
			], 'should correctly add second migration'

	'should perform raw SQL commands': t ->
		mg.setMigrationsData [[
			[ 'test_table', 'create', 'id INT' ]
			[ 'test_table', 'rawsql', 'INSERT INTO test_table (id) VALUES (1), (2), (5)' ]
		]]
		mg._justMigrate conn, 0

		rows = query.all 'SELECT * FROM test_table'
		test.deepEqual rows, [
			{id: 1}, {id: 2}, {id: 5}
		]

	'should return error if failed to migrate': t ->
		query 'DROP TABLE IF EXISTS test_table'
		mg.setRevision.sync null, conn, 0

		test.throws(
			-> mg._justMigrate conn, 1
			Error, /.*relation "test_table" does not exist.*/
		)


exports[NS].migrate =
	'should perform some or all migratons': t ->
		mg.migrate.sync null, conn, {dest_revision: 1}

		rows = query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		orows = query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.ok rows.length is 3 and
			rows[0].column_name is 'col0' and
			rows[1].column_name is 'col1' and
			rows[2].column_name is 'id' and
			rows[0].data_type is 'box' and
			rows[1].data_type is 'macaddr' and
			rows[2].data_type is 'integer' and
			orows.length is 1 and
			orows[0].column_name is 'id' and
			orows[0].data_type is 'integer',
			'should correctly perform part of migrations'

		revision = mg.getCurrentRevision.sync null, conn
		test.strictEqual revision, 1, 'should set correct revision'


		mg.migrate.sync null, conn

		rows = query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		orows = query.all 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.ok rows.length is 4 and
			rows[0].column_name is 'col0' and
			rows[1].column_name is 'col1' and
			rows[2].column_name is 'col2' and
			rows[3].column_name is 'id' and
			rows[0].data_type is 'box' and
			rows[1].data_type is 'macaddr' and
			rows[2].data_type is 'bigint' and
			rows[3].data_type is 'integer' and
			orows.length is 2 and
			orows[0].column_name is 'col0' and
			orows[1].column_name is 'id' and
			orows[0].data_type is 'lseg' and
			orows[1].data_type is 'integer',
			'should correctly perform all remaining migrations'

		revision = mg.getCurrentRevision.sync null, conn
		test.strictEqual revision, 3, 'should set correct revision'

	'should be able to migrate just one table': t ->
		rev0 = mg.getCurrentRevision.sync null, conn
		mg.migrate.sync null, conn, {dest_revision: 0, table: 'test_table'}
		rev1 = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev0, rev1, 'should not change version for one table'

		row = query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		exists = tables.tableExists.sync null, conn, 'other_table'

		test.deepEqual row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified table'
		test.ok not exists, 'migration for other tables should not have been performed'

	'should be able to migrate several tables': t ->
		rev0 = mg.getCurrentRevision.sync null, conn
		mg.migrate.sync null, conn, {dest_revision: 0, tables: ['no_such_table', 'test_table', 'other_table']}
		rev1 = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev0, rev1, 'should not change version'

		row = query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.deepEqual row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified tables'

		row = query.row 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'other_table' ORDER BY column_name"
		test.ok row, {
			column_name: 'id'
			data_type: 'integer'
		}, 'should correctly perform migration for specified tables'

	'should migrate verbosely if flag is set': t ->
		testLog = (message, func) ->
			_log = console.log
			_write = process.stdout.write
			log_times = 0
			console.log = (x) -> log_times++
			process.stdout.write = (x) -> log_times++
			func()
			console.log = _log
			process.stdout.write = _write
			test.ok log_times>0, message

		testLog 'should say something',
			-> mg.migrate.sync null, conn, {verbose: true}

		testLog 'should say something (when all migrations already completed)',
			-> mg.migrate.sync null, conn, {verbose: true}
