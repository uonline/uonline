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

test = require 'unit.js'
requireCovered = require '../require-covered.coffee'
sync = require 'sync'
config = require '../config'
async = require 'async'
anyDB = require 'any-db'
queryUtils = require '../lib/query_utils'
tables = requireCovered __dirname, '../lib/tables.coffee'
conn = null
query = null


mochasync = (f) ->
	(done) ->
		sync ->
			try
				f()
				done()
			catch ex
				done(ex)

cleanup = ->
	query 'DROP TABLE IF EXISTS test_table, akira'
	query 'DROP TYPE IF EXISTS test_enum'


exports.tables = {}

exports.tables.before = mochasync ->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	query = queryUtils.getFor conn
	cleanup()


exports.tables.after = mochasync ->
	cleanup()
	conn.end()


exports.tables.tableExists = mochasync ->
	query 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)'
	test.value( tables.tableExists.sync(null, conn, 'test_table') ).is true
	query 'DROP TABLE test_table'
	test.value( tables.tableExists.sync(null, conn, 'test_table') ).is false


exports.tables.create = mochasync ->
	tables.create.sync null, conn, 'akira', 'id INT'
	test.value( tables.tableExists.sync(null, conn, 'akira') ).is true  # should create table

	col_name = query.val "SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'akira'"
	test.string( col_name ).is 'id'  # and its columns


exports.tables.addCol = mochasync ->
	tables.create.sync null, conn, 'test_table', 'id INT'
	tables.addCol.sync null, conn, 'test_table', 'zoich INT'

	rows = query.all "SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'test_table'"
	test.number( rows.length ).is 2  # should create a new column


###
exports.tables.renameCol =
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


exports.tables.changeCol = (test) ->
	tables.create.sync null, conn, "test_table", "id SMALLINT"
	tables.changeCol.sync null, conn, "test_table", "id", "INTEGER"

	data_type = query.val "SELECT data_type FROM information_schema.columns WHERE table_name = 'test_table'"
	test.strictEqual data_type, "integer", "should change type of column"
	test.done()


exports.tables.changeDefault = (test) ->
	tables.create.sync null, conn, "test_table", "id SMALLINT DEFAULT 1"
	tables.changeDefault.sync null, conn, "test_table", "id", 2

	defaultValue = +query.val "SELECT column_default FROM information_schema.columns WHERE table_name = 'test_table'"
	test.strictEqual defaultValue, 2, "should change default value"
	test.done()


exports.tables.dropCol = (test) ->
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


exports.tables.createIndex = (test) ->
	tables.create.sync null, conn, 'test_table', 'id INTEGER'
	tables.createIndex.sync null, conn, 'test_table', 'id'

	rows = query.all "SELECT * FROM pg_indexes WHERE tablename='test_table' AND indexname='test_table_id'"
	test.strictEqual rows.length, 1, 'should create index'
	test.done()


exports.tables.createEnum = (test) -> sync ->
	tables.createEnum.sync null, conn, 'test_enum', "'bla', 'blabla', 'for the blah!'"

	enums = query.all "SELECT * FROM pg_type WHERE typname='test_enum'"
	test.strictEqual enums.length, 1, 'should create enum'

	values = query.val('SELECT enum_range(NULL::test_enum)')
	# other way: SELECT unnest(enum_range(NULL::mood))
	test.strictEqual values, '{bla,blabla,"for the blah!"}', 'should create correct enum'
	test.done()

###
