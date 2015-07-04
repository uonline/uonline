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
mg = requireCovered __dirname, '../lib/migration.coffee'
config = require '../config'
tables = require '../lib/tables'
queryUtils = require '../lib/query_utils'
sync = require 'sync'
anyDB = require 'any-db'

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
revisionBackup = null
migrationDataBackup = []

exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	query = queryUtils.getFor conn
	try
		revisionBackup = query.val 'SELECT revision FROM revision'
	catch e
		revisionBackup = null
	migrationDataBackup = mg.getMigrationsData()
	query 'DROP TABLE IF EXISTS test_table, other_table, revision'
	mg.setMigrationsData migrationData
).async()

exports.tearDown = ( ->
	query 'DROP TABLE IF EXISTS test_table, other_table, revision'
	mg.setMigrationsData migrationDataBackup
	if revisionBackup != null
		mg.setRevision.sync null, conn, revisionBackup
	conn.end()
).async()


exports.getCurrentRevision =
	'usual': (test) ->
		rev = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev, -1, 'should return -1 if revision table is not created'

		query 'CREATE TABLE revision (revision INT)'
		query 'INSERT INTO revision VALUES (945)'
		rev = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev, 945, 'should return current revision number'
		test.done()

	'exceptions': (test) ->
		test.throws(
			-> mg.getCurrentRevision.sync null, 'nonsense'
			Error
			'should fail on exceptions'
		)
		test.done()

	'connection errors': (test) ->
		fakeConn =
			query: (text, args, callback) ->
				callback new Error('THE_VERY_STRANGE_ERROR')
		test.throws(
			-> mg.getCurrentRevision.sync null, fakeConn
			Error
			'should fail on connection errors'
		)
		test.done()


exports.setRevision = (test) ->
	mg.setRevision.sync null, conn, 1
	exists = tables.tableExists.sync null, conn, 'revision'
	test.ok exists, 'table should have been created'

	rev = mg.getCurrentRevision.sync null, conn
	test.strictEqual rev, 1, 'revision should have been set'

	mg.setRevision.sync null, conn, 2
	rev = mg.getCurrentRevision.sync null, conn
	test.strictEqual rev, 2, 'revision should have been updated'
	test.done()


exports._justMigrate =
	'usual': (test) ->
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
		test.done()

	'rawsql': (test) ->
		mg.setMigrationsData [[
			[ 'test_table', 'create', 'id INT' ]
			[ 'test_table', 'rawsql', 'INSERT INTO test_table (id) VALUES (1), (2), (5)' ]
		]]
		mg._justMigrate conn, 0

		rows = query.all 'SELECT * FROM test_table'
		test.deepEqual rows, [
			{id: 1}, {id: 2}, {id: 5}
		], 'should perform raw SQL commands'
		test.done()

	'errors': (test) ->
		query 'DROP TABLE IF EXISTS test_table'
		mg.setRevision.sync null, conn, 0

		test.throws(
			-> mg._justMigrate conn, 1
			Error
			'should return error if failed to migrate'
		)
		test.done()


exports.migrate =
	'usual': (test) ->
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
		test.done()

	'for one table': (test) ->
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
		test.done()

	'for multiple tables': (test) ->
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
		test.done()

	'verbose': (test) ->
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

		test.done()
