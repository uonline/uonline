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
tables = requireCovered __dirname, '../lib/tables.coffee'
config = require '../config'
async = require 'async'
sync = require 'sync'
anyDB = require 'any-db'
queryUtils = require '../lib/query_utils'
conn = null
query = null


cleanup = ->
	query 'DROP TABLE IF EXISTS test_table, akira'
	query 'DROP TYPE IF EXISTS test_enum'

exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	query = queryUtils.getFor conn
	cleanup()
).async()


exports.tearDown = (->
	cleanup()
	conn.end()
).async()


exports.tableExists = (test) ->
	query 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)'
	test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), true,
		'should return true if table exists'
	query 'DROP TABLE test_table'
	test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), false,
		'should return false if table does not exist'
	test.done()


exports.create = (test) ->
	tables.create.sync null, conn, 'akira', 'id INT'
	test.strictEqual tables.tableExists.sync(null, conn, 'akira'), true, 'should create table'

	col_name = query.val "SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'akira'"
	test.strictEqual col_name, 'id', 'and its columns'
	test.done()


exports.addCol = (test) ->
	tables.create.sync null, conn, 'test_table', 'id INT'
	tables.addCol.sync null, conn, 'test_table', 'zoich INT'

	rows = query.all "SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'test_table'"
	test.strictEqual rows.length, 2, 'should create a new column'
	test.done()


exports.renameCol =
	testNoErrors: (test) ->
		tables.create.sync null, conn, "test_table", "id INTEGER"
		tables.renameCol.sync null, conn, "test_table", "id", "col"

		col = query.row "SELECT column_name, data_type FROM information_schema.columns "+
			"WHERE table_name = 'test_table'"
		test.strictEqual col.column_name, "col", "should rename column"
		test.strictEqual col.data_type, "integer", "should not alter its type"
		test.done()

	testNoTable: (test) ->
		test.throws(
			-> tables.renameCol.sync null, conn, "test_table", "id", "col"
			Error
			'should return error if tried to rename column from nonexistent table'
		)
		test.done()

	testNoColumn: (test) ->
		tables.create.sync null, conn, "test_table", "id INT"
		test.throws(
			-> tables.renameCol.sync null, conn, "test_table", "noSuchCol", "col"
			Error
			'should return error if tried to rename nonexistent column'
		)
		test.done()


exports.changeCol = (test) ->
	tables.create.sync null, conn, "test_table", "id SMALLINT"
	tables.changeCol.sync null, conn, "test_table", "id", "INTEGER"

	data_type = query.val "SELECT data_type FROM information_schema.columns WHERE table_name = 'test_table'"
	test.strictEqual data_type, "integer", "should change type of column"
	test.done()


exports.changeDefault = (test) ->
	tables.create.sync null, conn, "test_table", "id SMALLINT DEFAULT 1"
	tables.changeDefault.sync null, conn, "test_table", "id", 2

	defaultValue = +query.val "SELECT column_default FROM information_schema.columns WHERE table_name = 'test_table'"
	test.strictEqual defaultValue, 2, "should change default value"
	test.done()


exports.dropCol = (test) ->
	# single column
	tables.create.sync null, conn, "test_table", "id INT"
	tables.addCol.sync null, conn, "test_table", "col INT"
	tables.dropCol.sync null, conn, "test_table", "col"

	rows = query.all "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='test_table'"
	test.deepEqual rows, [
		{column_name: 'id', data_type: 'integer'}
	], "should remove specified column and not another"

	# multiple columns
	tables.addCol.sync null, conn, "test_table", "col INT"
	tables.addCol.sync null, conn, "test_table", "col2 TEXT"
	tables.dropCol.sync null, conn, "test_table", "id", "col2"

	rows = query.all "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='test_table'"
	test.deepEqual rows, [
		{column_name: 'col', data_type: 'integer'}
	], "should remove only specified columns"
	test.done()


exports.createIndex = (test) ->
	tables.create.sync null, conn, 'test_table', 'id INTEGER'
	tables.createIndex.sync null, conn, 'test_table', 'id'

	rows = query.all "SELECT * FROM pg_indexes WHERE tablename='test_table' AND indexname='test_table_id'"
	test.strictEqual rows.length, 1, 'should create index'
	test.done()


exports.createEnum = (test) -> sync ->
	tables.createEnum.sync null, conn, 'test_enum', "'bla', 'blabla', 'for the blah!'"

	enums = query.all "SELECT * FROM pg_type WHERE typname='test_enum'"
	test.strictEqual enums.length, 1, 'should create enum'

	values = query.val('SELECT enum_range(NULL::test_enum)')
	# other way: SELECT unnest(enum_range(NULL::mood))
	test.strictEqual values, '{bla,blabla,"for the blah!"}', 'should create correct enum'
	test.done()

