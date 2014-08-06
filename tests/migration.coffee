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

config = require '../config.js'
tables = require '../lib/tables.js'
mg = require '../lib-cov/migration'
async = require 'async'
sync = require 'sync'
anyDB = require 'any-db'

conn = null

query = (str, values) ->
	conn.query.sync(conn, str, values).rows

queryOne = (str, values) ->
	rows = query(str, values)
	throw new Error('In query:\n' + query + '\nExpected one row, but got ' + rows.length) if rows.length isnt 1
	rows[0]


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


exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	query 'DROP TABLE IF EXISTS test_table, other_table, revision'
	mg.setMigrationsData migrationData
).async()


exports.tearDown = (done) ->
	conn.end()
	done()


exports.getCurrentRevision =
	'usual': (test) ->
		async.series [
			(callback) ->
				mg.getCurrentRevision conn, callback
			(callback) ->
				conn.query 'CREATE TABLE revision (revision INT)', [], callback
			(callback) ->
				conn.query 'INSERT INTO revision VALUES (945)', [], callback
			(callback) ->
				mg.getCurrentRevision conn, callback
		], (error, result) ->
			test.ifError error
			test.strictEqual result[0], -1, 'should return -1 if revision table is not created'
			test.strictEqual result[3], 945, 'should return current revision number'
			test.done()

	'exceptions': (test) ->
		async.parallel [
			(callback) ->
				mg.getCurrentRevision 'nonsense', callback
		], (error, result) ->
			test.ok !!error, 'should fail on exceptions'
			test.done()

	'connection errors': (test) ->
		fakeConn =
			query: (text, args, callback) ->
				callback 'THE_VERY_STRANGE_ERROR'
		async.parallel [
			(callback) ->
				mg.getCurrentRevision fakeConn, callback
		], (error, result) ->
			test.ok !!error, 'should fail on connection errors'
			test.done()


exports.setRevision = (test) ->
	async.series [
		(callback) ->
			mg.setRevision conn, 1, callback
		(callback) ->
			tables.tableExists conn, 'revision', callback
		(callback) ->
			mg.getCurrentRevision conn, callback
		(callback) ->
			mg.setRevision conn, 2, callback
		(callback) ->
			mg.getCurrentRevision conn, callback
	], (error, result) ->
		test.ifError error
		test.ok result[1], 'table should have been created'
		test.strictEqual result[2], 1, 'revision should have been set'
		test.strictEqual result[4], 2, 'revision should have been updated'
		test.done()


exports.migrateOne =
	'usual': (test) ->
		async.series [
			(callback) ->
				mg.migrateOne conn, 0, callback
			(callback) ->
				conn.query 'SELECT column_name FROM information_schema.columns ' +
					"WHERE table_name = 'test_table' ORDER BY column_name", [], callback
			(callback) ->
				conn.query 'SELECT column_name FROM information_schema.columns ' +
					"WHERE table_name = 'other_table' ORDER BY column_name", [], callback
			(callback) ->
				mg.migrateOne conn, 1, callback
			(callback) ->
				mg.migrateOne conn, 1, callback
			(callback) ->
				conn.query 'SELECT column_name FROM information_schema.columns ' +
					"WHERE table_name = 'test_table' ORDER BY column_name", [], callback
			(callback) ->
				conn.query 'SELECT column_name FROM information_schema.columns ' +
					"WHERE table_name = 'other_table' ORDER BY column_name", [], callback
			(callback) ->
				mg.getCurrentRevision conn, callback
		], (error, result) ->
			test.ifError error, 'should not fail if destination revision is current'
			test.ok result[1].rows.length is 1 and
				result[1].rows[0].column_name is 'id' and
				result[2].rows.length is 1 and
				result[2].rows[0].column_name is 'id',
				'should correctly perform first migration'
			test.ok result[5].rows.length is 3 and
				result[5].rows[0].column_name is 'col0' and
				result[5].rows[1].column_name is 'col1' and
				result[5].rows[2].column_name is 'id' and
				result[6].rows.length is 1 and
				result[6].rows[0].column_name is 'id',
				'should correctly add second migration'
			test.strictEqual result[7], 1, 'should update revision'
			test.done()

	'too new': (test) ->
		async.series [
			(callback) ->
				mg.migrateOne conn, 1, callback
		], (error, result) ->
			test.ok error, 'should fail if destination revision is too new'
			test.done()

	'too old': (test) ->
		async.series [
			(callback) ->
				mg.migrateOne conn, 0, callback
			(callback) ->
				mg.migrateOne conn, 1, callback
			(callback) ->
				mg.migrateOne conn, 0, callback
		], (error, result) ->
			test.ok error, 'should fail if destination revision is too old'
			test.done()

	'errors': (test) ->
		async.series [
			(callback) ->
				conn.query 'DROP TABLE IF EXISTS test_table', callback
			(callback) ->
				mg.setRevision conn, 0, callback
			(callback) ->
				mg.migrateOne conn, 1, callback
		], (error, result) ->
			test.ok error, 'should return error if failed to migrate'
			test.done()


exports.migrate =
	'usual': (test) ->
		mg.migrate.sync null, conn, {dest_revision: 1}
		
		rows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		orows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
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
		
		rows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		orows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
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
		
		rows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		exists = tables.tableExists.sync null, conn, 'other_table'
		
		test.ok rows.length is 1 and
			rows[0].column_name is 'id',
			'should correctly perform migration for specified table'
		test.ok not exists, 'migration for other tables should not have been performed'
		test.done()
	
	'for multiple tables': (test) ->
		rev0 = mg.getCurrentRevision.sync null, conn
		mg.migrate.sync null, conn, {dest_revision: 0, tables: ['no_such_table', 'test_table', 'other_table']}
		rev1 = mg.getCurrentRevision.sync null, conn
		test.strictEqual rev0, rev1, 'should not change version'
		
		rows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.ok rows.length is 1 and
			rows[0].column_name is 'id',
			'should correctly perform migration for specified tables'
		
		rows = query 'SELECT column_name, data_type FROM information_schema.columns ' +
			"WHERE table_name = 'test_table' ORDER BY column_name"
		test.ok rows.length is 1 and
			rows[0].column_name is 'id',
			'should correctly perform migration for specified tables'
		test.done()
	
	'verbose': (test) ->
		log = console.log
		log_times = 0
		console.log = (smth) -> log_times++
		mg.migrate.sync null, conn, {verbose: true}
		console.log = log
		
		test.ok log_times>0, 'should say something'
		test.done()

fixTest = (obj) ->
	for attr of obj
		if attr is 'setUp' or attr is 'tearDown'
			continue
		
		if obj[attr] instanceof Function
			obj[attr] = ((origTestFunc, t) -> (test) ->
					console.log(t)
					origTestFunc(test)
				)(obj[attr], attr)
		else
			fixTest(obj[attr])
fixTest exports
