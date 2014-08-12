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
tables = require '../lib-cov/tables'
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


cleanup = ->
	query 'DROP TABLE IF EXISTS test_table, akira'
	query 'DROP TYPE IF EXISTS test_enum'

exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	cleanup()
).async()


exports.tearDown = (->
	cleanup()
	conn.end()
).async()


exports.tableExists = (test) ->
	conn.query.sync conn, 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)', []
	test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), true,
		'should return true if table exists'
	conn.query.sync conn, 'DROP TABLE test_table', []
	test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), false,
		'should return false if table does not exist'
	test.done()


exports.create = (test) ->
	tables.create.sync null, conn, 'akira', 'id INT'
	test.strictEqual tables.tableExists.sync(null, conn, 'akira'), true, 'should create table'
	dsc = conn.query.sync conn,
		"SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'akira'", []
	test.strictEqual dsc.rows[0].result, 'id', 'and its columns'
	test.done()


exports.addCol = (test) ->
	tables.create.sync null, conn, 'test_table', 'id INT'
	tables.addCol.sync null, conn, 'test_table', 'zoich INT'
	dsc = conn.query.sync conn,
		"SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'test_table'", []
	test.strictEqual dsc.rows.length, 2, 'should create a new column'
	test.done()


exports.renameCol =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				tables.create conn, "test_table", "id INTEGER", callback
			(callback) ->
				tables.renameCol conn, "test_table", "id", "col", callback
			(callback) ->
				conn.query "SELECT column_name, data_type FROM information_schema.columns " +
					"WHERE table_name = 'test_table'", [], callback
		], (error, result) ->
			test.ifError error
			test.strictEqual result[2].rows[0].column_name, "col", "should rename column"
			test.strictEqual result[2].rows[0].data_type, "integer", "should not alter its type"
			test.done()

	testNoTable: (test) ->
		tables.renameCol conn, "test_table", "id", "col", (error, result) ->
			test.ok error, "No table - no renaming"
			test.done()

	testNoColumn: (test) ->
		async.series [
			(callback) ->
				tables.create conn, "test_table", "id INT(9)", callback
			(callback) ->
				tables.renameCol conn, "test_table", "noSuchCol", "col", callback
		], (error, result) ->
			test.ok error, "No column - no renaming"
			test.done()


exports.changeCol = (test) ->
	async.series [
		(callback) ->
			tables.create conn, "test_table", "id SMALLINT", callback
		(callback) ->
			tables.changeCol conn, "test_table", "id", "INTEGER", callback
		(callback) ->
			conn.query "SELECT column_name, data_type FROM information_schema.columns "+
				"WHERE table_name = 'test_table'", [], callback
	], (error, result) ->
		test.ifError error
		test.strictEqual result[2].rows[0].data_type, "integer", "should change type of column"
		test.done()


exports.dropCol = (test) ->
	async.series [
		(callback) ->
			tables.create conn, "test_table", "id INTEGER", callback
		(callback) ->
			tables.addCol conn, "test_table", "col INTEGER", callback
		(callback) ->
			tables.dropCol conn, "test_table", "col", callback
		(callback) ->
			conn.query "SELECT column_name, data_type FROM information_schema.columns "+
				"WHERE table_name = 'test_table'", [], callback
	], (error, result) ->
		test.ifError error
		test.strictEqual result[3].rows.length, 1, "should remove column"
		test.strictEqual result[3].rows[0].column_name, "id", "should remove specified column and not another"
		test.done()


exports.createIndex = (test) ->
	async.series [
		(callback) ->
			tables.create conn, 'test_table', 'id INTEGER', callback
		(callback) ->
			tables.createIndex conn, 'test_table', 'id', callback
		(callback) ->
			conn.query "SELECT * FROM pg_indexes WHERE tablename='test_table' AND indexname='test_table_id'", callback
	], (error, result) ->
		test.ifError error
		test.strictEqual result[2].rows.length, 1, 'should create index'
		test.done()


exports.createEnum = (test) -> sync ->
	tables.createEnum.sync null, conn, 'test_enum', "'bla', 'blabla', 'for the blah!'"

	enums = query "SELECT * FROM pg_type WHERE typname='test_enum'"
	test.strictEqual enums.length, 1, 'should create enum'

	values = queryOne('SELECT enum_range(NULL::test_enum)').enum_range
	# other way: SELECT unnest(enum_range(NULL::mood))
	test.strictEqual values, '{bla,blabla,"for the blah!"}', 'should create correct enum'
	test.done()

