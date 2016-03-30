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
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
sugar = require 'sugar'
queryUtils = require '../lib/query_utils'

tables = requireCovered __dirname, '../lib/tables.coffee'

_conn = null
conn = null
query = null


exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)

exports[NS].beforeEach = t ->
	conn = transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = t ->
	conn.rollback.sync(conn)


exports[NS].tableExists =
	'should return if table exists': t ->
		query 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)'
		test.isTrue tables.tableExists.sync(null, conn, 'test_table')
		query 'DROP TABLE test_table'
		test.isFalse tables.tableExists.sync(null, conn, 'test_table')


exports[NS].create =
	'should create table and its columns': t ->
		tables.create.sync null, conn, 'akira', 'id INT, name TEXT'
		test.isTrue tables.tableExists.sync(null, conn, 'akira')

		names = query.val "SELECT json_agg(column_name) FROM information_schema.columns WHERE table_name = 'akira'"
		test.deepEqual names, ['id', 'name']


exports[NS].addCol =
	beforeEach: t ->
		tables.create.sync null, conn, 'test_table', 'id INT'
		this.cols = -> query.all "SELECT column_name FROM information_schema.columns WHERE table_name = 'test_table'"

	'should create a new column': t ->
		tables.addCol.sync null, conn, 'test_table', 'zoich INT'
		test.strictEqual this.cols().length, 2


exports[NS].renameCol =
	"should rename column and not alter its type": t ->
		tables.create.sync null, conn, "test_table", "id INTEGER"
		tables.renameCol.sync null, conn, "test_table", "id", "col"

		col = query.row "SELECT * FROM information_schema.columns WHERE table_name = 'test_table'"
		test.strictEqual col.column_name, "col"
		test.strictEqual col.data_type, "integer"

	'should return error if tried to rename column from nonexistent table': t ->
		test.throwsPgError(
			# uses _conn, I don't know why it doesn't work with transaction
			# renamed _conn to conn, seems working now
			-> tables.renameCol.sync null, conn, "test_table", "id", "col"
			'42P01'  # relation "test_table" does not exist
		)

	'should return error if tried to rename nonexistent column': t ->
		tables.create.sync null, conn, "test_table", "id INT"
		test.throwsPgError(
			-> tables.renameCol.sync null, conn, "test_table", "noSuchCol", "col"
			'42703'  # column "nosuchcol" does not exist
		)


exports[NS].changeCol =
	beforeEach: t ->
		tables.create.sync null, conn, "test_table", "id SMALLINT"
		this.col = -> query.row "SELECT * FROM information_schema.columns WHERE table_name = 'test_table'"

	"should change type of column": t ->
		tables.changeCol.sync null, conn, "test_table", "id", "INTEGER"
		test.strictEqual this.col().data_type, "integer"


exports[NS].changeDefault =
	beforeEach: t ->
		tables.create.sync null, conn, "test_table", "id SMALLINT DEFAULT 1"
		this.defaultValue = -> +query.val "SELECT column_default FROM information_schema.columns WHERE table_name = 'test_table'"

	"should change default value": t ->
		tables.changeDefault.sync null, conn, "test_table", "id", 2
		test.strictEqual this.defaultValue(), 2


exports[NS].dropCol =
	beforeEach: t ->
		tables.create.sync null, conn, "test_table", "id INT"
		tables.addCol.sync null, conn, "test_table", "col INT"
		tables.addCol.sync null, conn, "test_table", "col2 TEXT"
		this.cols = -> query.all "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='test_table'"

	"should remove specified column": t ->
		tables.dropCol.sync null, conn, "test_table", "col"
		test.deepEqual this.cols(), [
			{column_name: 'id', data_type: 'integer'}
			{column_name: 'col2', data_type: 'text'}
		]

	"should remove multiple columns": t ->
		tables.dropCol.sync null, conn, "test_table", "id", "col2"
		test.deepEqual this.cols(), [
			{column_name: 'col', data_type: 'integer'}
		]


exports[NS].createIndex =
	beforeEach: t ->
		tables.create.sync null, conn, 'test_table', 'id INTEGER'
		this.indexes = -> query.all "SELECT * FROM pg_indexes WHERE tablename='test_table' AND indexname='test_table_id'"

	'should create index': t ->
		tables.createIndex.sync null, conn, 'test_table', 'id'
		test.strictEqual this.indexes().length, 1


exports[NS].createEnum =
	beforeEach: t ->
		tables.createEnum.sync null, conn, 'test_enum', "'bla', 'blabla', 'for the blah!'"
		this.enums = -> query.all "SELECT * FROM pg_type WHERE typname='test_enum'"
		this.values = -> query.val 'SELECT enum_range(NULL::test_enum)'
		# other way: SELECT unnest(enum_range(NULL::mood))

	'should create enum': t ->
		test.strictEqual this.enums().length, 1, 'should create enum'
		test.strictEqual this.values(), '{bla,blabla,"for the blah!"}'
