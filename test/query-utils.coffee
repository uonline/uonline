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

NS = 'query-utils'; exports[NS] = {}  # namespace
{test, requireCovered, legacyConfig} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll
mg = require '../lib/migration'
tables = require '../lib/tables'

queryUtils = requireCovered __dirname, '../lib/query_utils.coffee'

_conn = null
conn = null
query = null

exports[NS].before = ->
	_conn = promisifyAll anyDB.createConnection(legacyConfig.DATABASE_URL_TEST)

exports[NS].beforeEach = async ->
	conn = promisifyAll transaction(_conn)
	query = queryUtils.getFor conn
	await query 'CREATE TABLE test_table (id INT, data TEXT)'
	await query "INSERT INTO test_table (id, data) VALUES (1, 'first')"
	await query "INSERT INTO test_table (id, data) VALUES (2, 'second')"

exports[NS].afterEach = ->
	conn.rollbackAsync()


exports[NS].itself = async ->
	result = await query "INSERT INTO test_table (id, data) VALUES (3, 'third')"
	test.deepEqual typeof(result), 'object', 'should return dbConnection.query result'
	test.deepEqual result.command, 'INSERT', 'should return correct dbConnection.query result'

	result = await query.all 'SELECT * FROM test_table'
	test.strictEqual result.length, 3, 'should execute the given query'


exports[NS].all = async ->
	rows = await query.all 'SELECT * FROM test_table ORDER BY id'
	test.deepEqual rows, [
		{id: 1, data: 'first'}
		{id: 2, data: 'second'}
	], 'should return rows from query'


exports[NS].row =
	'should return the first and only row from query': async ->
		row = await query.row 'SELECT * FROM test_table WHERE id = 1'
		test.deepEqual row, {id: 1, data: 'first'}

	'should throw error if more than one row returned': async ->
		await test.isRejected(
			query.row('SELECT * FROM test_table')
			/In query:\nSELECT \* FROM test_table\nExpected one row, but got 2/
		)

	'should throw error if no rows returned': async ->
		await test.isRejected(
			query.row('SELECT * FROM test_table WHERE id = 3')
			/In query:\nSELECT \* FROM test_table WHERE id = 3\nExpected one row, but got 0/
		)


exports[NS].val =
	'should return the first and only value from the first and only row': async ->
		data = await query.val 'SELECT data FROM test_table WHERE id = 2'
		test.deepEqual data, 'second'

	'should throw error if more than one value returned': async ->
		await test.isRejected(
			query.val('SELECT id, data FROM test_table WHERE id = 2')
			/In query:\nSELECT id, data FROM test_table WHERE id = 2\nExpected one value, but got 2 \(id, data\)/
		)

	'should throw error if more than one row returned': async ->
		await test.isRejected(
			query.val('SELECT * FROM test_table')
			/In query:\nSELECT \* FROM test_table\nExpected one row, but got 2/
		)

	'should throw error if no rows returned': async ->
		await test.isRejected(
			query.val('SELECT * FROM test_table WHERE id = 3')
			/In query:\nSELECT \* FROM test_table WHERE id = 3\nExpected one row, but got 0/
		)


exports[NS].ins = async ->
	await query.ins 'test_table', id: 3, data: 'third'
	count = + await query.val 'SELECT count(*) FROM test_table'
	data = await query.val 'SELECT data FROM test_table WHERE id = 3'

	test.strictEqual count, 3, 'should insert one row'
	test.strictEqual data, 'third', 'should add strings correctly'


exports[NS].doInTransaction =
	beforeEach: async ->
		this.count = async -> + await query.val 'SELECT count(*) FROM test_table'

	'should execute function and commit transaction': async ->
		await queryUtils.doInTransaction conn, async (tx) ->
			tx.queryAsync "INSERT INTO test_table VALUES (3, 'something')"
			await tx.queryAsync "INSERT INTO test_table VALUES (4, 'very something')"
		test.strictEqual (await this.count()), 4

	'should rollback transaction and throw on query error': async ->
		test.isRejectedWithPgError(
			queryUtils.doInTransaction conn, async (tx) ->
				await tx.queryAsync "INSERT INTO test_table VALUES (3, 'something')"
				await tx.queryAsync "INSERT INTO no_such_table VALUES ('nothing')"
			'42P01'  # relation "no_such_table" does not exist
		)
		test.strictEqual (await this.count()), 2

	'should rollback transaction (and make connection usable immediately) on first query error': async ->
		test.isRejectedWithPgError(
			queryUtils.doInTransaction conn, async (tx) ->
				await tx.queryAsync "SELECT first transaction query with error"
			'42601'  # syntax error at or near "transaction"
		)
		test.strictEqual (await this.count()), 2

	'should rollback transaction and throw on non-query error': async ->
		await test.isRejected(
			queryUtils.doInTransaction conn, async (tx) ->
				await tx.queryAsync "INSERT INTO test_table VALUES (3, 'something')"
				throw new Error 'something fell up and broke down'
			/something fell up and broke down/
		)
		test.strictEqual (await this.count()), 2

	'should correctly perform after some errors': async ->
		try await queryUtils.doInTransaction conn, async (tx) -> throw new Error 'oups'
		try await queryUtils.doInTransaction conn, async (tx) -> await tx.queryAsync "SELECT fail"
		try await queryUtils.doInTransaction conn, async (tx) ->
			await tx.queryAsync "INSERT INTO test_table VALUES (-1, 'should rollback')"
			await tx.queryAsync "SELECT fail"

		await queryUtils.doInTransaction conn, async (tx) ->
			await tx.queryAsync "INSERT INTO test_table VALUES (5, 'one more thing')"
		test.strictEqual (await this.count()), 3


exports[NS].unsafeInsert =
	'should insert passed args': async ->
		await queryUtils.unsafeInsert conn, 'test_table', {id: 3, data: 'smth'}
		await queryUtils.unsafeInsert conn, 'test_table', {id: 4, data: 'other'}

		rows = await query.all "SELECT * FROM test_table"
		test.deepEqual rows, [
			{ id: 1, data: 'first' },
			{ id: 2, data: 'second' },
			{ id: 3, data: 'smth' },
			{ id: 4, data: 'other' },
		]

	'should insert objects as json': async ->
		await query "ALTER TABLE test_table ADD COLUMN params json"
		await queryUtils.unsafeInsert conn, 'test_table', {id: 3, data: 'smth', params: [1,2]}
		await queryUtils.unsafeInsert conn, 'test_table', {id: 4, data: 'other', params: {'works': true}}

		rows = await query.all "SELECT * FROM test_table"
		test.deepEqual rows, [
			{ id: 1, data: 'first', params: null },
			{ id: 2, data: 'second', params: null },
			{ id: 3, data: 'smth', params: [1, 2] },
			{ id: 4, data: 'other', params: {'works': true} },
		]

	'should insert dates as timestamps': async ->
		now = new Date()
		longTimeAgo = new Date(2015, 0, 1, 12, 23)
		await query "ALTER TABLE test_table ADD COLUMN created_at TIMESTAMPTZ"
		await queryUtils.unsafeInsert conn, 'test_table', {id: 3, created_at: now}
		await queryUtils.unsafeInsert conn, 'test_table', {id: 4, created_at: longTimeAgo}

		rows = await query.all "SELECT * FROM test_table"
		test.deepEqual rows, [
			{ id: 1, data: 'first', created_at: null },
			{ id: 2, data: 'second', created_at: null },
			{ id: 3, data: null, created_at: now },
			{ id: 4, data: null, created_at: longTimeAgo },
		]
