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

NS = 'tables'; exports[NS] = {}  # namespace
{test, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll
sugar = require 'sugar'
queryUtils = require '../lib/query_utils'

tables = requireCovered __dirname, '../lib/tables.coffee'

_conn = null
conn = null
query = null


exports[NS].before = ->
	_conn = promisifyAll anyDB.createConnection(config.DATABASE_URL_TEST)

exports[NS].beforeEach = async ->
	conn = promisifyAll transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = ->
	conn.rollbackAsync()


exports[NS].tableExists =
	'should return if table exists': async ->
		await query 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)'
		test.isTrue await tables.tableExists conn, 'test_table'
		await query 'DROP TABLE test_table'
		test.isFalse await tables.tableExists conn, 'test_table'


exports[NS].create =
	'should create table and its columns': async ->
		await tables.create conn, 'akira', 'id INT, name TEXT'
		test.isTrue await tables.tableExists conn, 'akira'

		names = await query.val(
			"SELECT json_agg(column_name) FROM information_schema.columns WHERE table_name = 'akira'")
		test.deepEqual names, ['id', 'name']


exports[NS].addCol =
	beforeEach: async ->
		await tables.create conn, 'test_table', 'id INT'

	'should create a new column': async ->
		await tables.addCol conn, 'test_table', 'zoich INT'
		cols = await query.all "SELECT column_name FROM information_schema.columns WHERE table_name = 'test_table'"
		test.strictEqual cols.length, 2


exports[NS].renameCol =
	"should rename column and not alter its type": async ->
		await tables.create conn, "test_table", "id INTEGER"
		await tables.renameCol conn, "test_table", "id", "col"

		col = await query.row "SELECT * FROM information_schema.columns WHERE table_name = 'test_table'"
		test.strictEqual col.column_name, "col"
		test.strictEqual col.data_type, "integer"

	'should return error if tried to rename column from nonexistent table': async ->
		await test.isRejectedWithPgError(
			tables.renameCol conn, "test_table", "id", "col"
			'42P01'  # relation "test_table" does not exist
		)

	'should return error if tried to rename nonexistent column': async ->
		await tables.create conn, "test_table", "id INT"
		await test.isRejectedWithPgError(
			tables.renameCol conn, "test_table", "noSuchCol", "col"
			'42703'  # column "nosuchcol" does not exist
		)


exports[NS].changeCol =
	beforeEach: async ->
		await tables.create conn, "test_table", "id SMALLINT"

	"should change type of column": async ->
		await tables.changeCol conn, "test_table", "id", "INTEGER"
		col = await query.row "SELECT * FROM information_schema.columns WHERE table_name = 'test_table'"
		test.strictEqual col.data_type, "integer"


exports[NS].changeDefault =
	beforeEach: async ->
		await tables.create conn, "test_table", "id SMALLINT DEFAULT 1"

	"should change default value": async ->
		await tables.changeDefault conn, "test_table", "id", 2
		defaultValue = + await query.val "SELECT column_default FROM information_schema.columns WHERE table_name = 'test_table'"
		test.strictEqual defaultValue, 2


exports[NS].dropCol =
	beforeEach: async ->
		await tables.create conn, "test_table", "id INT"
		await tables.addCol conn, "test_table", "col INT"
		await tables.addCol conn, "test_table", "col2 TEXT"
		this.cols = -> query.all "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='test_table'"

	"should remove specified column": async ->
		await tables.dropCol conn, "test_table", "col"
		test.deepEqual (await this.cols()), [
			{column_name: 'id', data_type: 'integer'}
			{column_name: 'col2', data_type: 'text'}
		]

	"should remove multiple columns": async ->
		await tables.dropCol conn, "test_table", "id", "col2"
		test.deepEqual (await this.cols()), [
			{column_name: 'col', data_type: 'integer'}
		]


exports[NS].createIndex =
	beforeEach: async ->
		await tables.create conn, 'test_table', 'id INTEGER'

	'should create index': async ->
		await tables.createIndex conn, 'test_table', 'id'
		indexes = await query.all "SELECT * FROM pg_indexes WHERE tablename='test_table' AND indexname='test_table_id'"
		test.strictEqual indexes.length, 1


exports[NS].createEnum =
	beforeEach: async ->
		await tables.createEnum conn, 'test_enum', "'bla', 'blabla', 'for the blah!'"

	'should create enum': async ->
		# other way: SELECT unnest(enum_range(NULL::mood))
		enums = await query.all "SELECT * FROM pg_type WHERE typname='test_enum'"
		values = await query.val 'SELECT enum_range(NULL::test_enum)'
		test.strictEqual enums.length, 1, 'should create enum'
		test.strictEqual values, '{bla,blabla,"for the blah!"}'
