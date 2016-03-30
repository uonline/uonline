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
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
mg = require '../lib/migration'
tables = require '../lib/tables'

queryUtils = requireCovered __dirname, '../lib/query_utils.coffee'

_conn = null
conn = null
query = null

exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	# mg.migrate.sync mg, _conn

exports[NS].beforeEach = t ->
	conn = transaction(_conn)
	conn.query.sync conn, 'CREATE TABLE test_table (id INT, data TEXT)'
	conn.query.sync conn, "INSERT INTO test_table (id, data) VALUES (1, 'first')"
	conn.query.sync conn, "INSERT INTO test_table (id, data) VALUES (2, 'second')"
	query = queryUtils.getFor conn

exports[NS].afterEach = t ->
	conn.rollback.sync(conn)


exports[NS].itself = t ->
	result = query "INSERT INTO test_table (id, data) VALUES (3, 'third')"
	test.deepEqual typeof(result), 'object', 'should return dbConnection.query result'
	test.deepEqual result.command, 'INSERT', 'should return correct dbConnection.query result'

	result = query.all 'SELECT * FROM test_table'
	test.strictEqual result.length, 3, 'should execute the given query'


exports[NS].all = t ->
	rows = query.all 'SELECT * FROM test_table ORDER BY id'
	test.deepEqual rows, [
		{id: 1, data: 'first'}
		{id: 2, data: 'second'}
	], 'should return rows from query'


exports[NS].row =
	'should return the first and only row from query': t ->
		row = query.row 'SELECT * FROM test_table WHERE id = 1'
		test.deepEqual row, {id: 1, data: 'first'}

	'should throw error if more than one row returned': t ->
		test.throws(
			-> query.row 'SELECT * FROM test_table'
			Error, 'In query:\nSELECT * FROM test_table\nExpected one row, but got 2'
		)

	'should throw error if no rows returned': t ->
		test.throws(
			-> query.row 'SELECT * FROM test_table WHERE id = 3'
			Error, 'In query:\nSELECT * FROM test_table WHERE id = 3\nExpected one row, but got 0'
		)


exports[NS].val =
	'should return the first and only value from the first and only row': t ->
		data = query.val 'SELECT data FROM test_table WHERE id = 2'
		test.deepEqual data, 'second'

	'should throw error if more than one value returned': t ->
		test.throws(
			-> query.val 'SELECT id, data FROM test_table WHERE id = 2'
			Error, 'In query:\nSELECT id, data FROM test_table WHERE id = 2\nExpected one value, but got 2 (id, data)'
		)

	'should throw error if more than one row returned': t ->
		test.throws(
			-> query.val 'SELECT * FROM test_table'
			Error, 'In query:\nSELECT * FROM test_table\nExpected one row, but got 2'
		)

	'should throw error if no rows returned': t ->
		test.throws(
			-> query.val 'SELECT * FROM test_table WHERE id = 3'
			Error, 'In query:\nSELECT * FROM test_table WHERE id = 3\nExpected one row, but got 0'
		)


exports[NS].ins = t ->
	query.ins 'test_table', id: 3, data: 'third'
	count = +query.val 'SELECT count(*) FROM test_table'
	data = query.val 'SELECT data FROM test_table WHERE id = 3'

	test.strictEqual count, 3, 'should insert one row'
	test.strictEqual data, 'third', 'should add strings correctly'


exports[NS].doInTransaction =
	beforeEach: t ->
		this.count = -> +query.val 'SELECT count(*) FROM test_table'

	'should execute function and commit transaction': t ->
		queryUtils.doInTransaction conn, (tx) ->
			tx.query.sync tx, "INSERT INTO test_table VALUES (3, 'something')"
			tx.query.sync tx, "INSERT INTO test_table VALUES (4, 'very something')"
		test.strictEqual this.count(), 4

	'should rollback transaction and throw on query error': t ->
		test.throwsPgError(
			-> queryUtils.doInTransaction conn, (tx) ->
				tx.query.sync tx, "INSERT INTO test_table VALUES (3, 'something')"
				tx.query.sync tx, "INSERT INTO no_such_table VALUES ('nothing')"
			'42P01'  # relation "no_such_table" does not exist
		)
		test.strictEqual this.count(), 2

	'should rollback transaction (and make connection usable immediately) on first query error': t ->
		test.throwsPgError(
			-> queryUtils.doInTransaction conn, (tx) ->
				tx.query.sync tx, "SELECT first transaction query with error"
			'42601'  # syntax error at or near "transaction"
		)
		test.strictEqual this.count(), 2

	'should rollback transaction and throw on non-query error': t ->
		test.throws(
			-> queryUtils.doInTransaction conn, (tx) ->
				tx.query.sync tx, "INSERT INTO test_table VALUES (3, 'something')"
				throw new Error 'something fell up and broke down'
			Error, 'something fell up and broke down'
		)
		test.strictEqual this.count(), 2

	'should correctly perform after some errors': t ->
		try queryUtils.doInTransaction conn, (tx) -> throw new Error 'oups'
		try queryUtils.doInTransaction conn, (tx) -> tx.query.sync tx, "SELECT fail"
		try queryUtils.doInTransaction conn, (tx) ->
			tx.query.sync tx, "INSERT INTO test_table VALUES (-1, 'should rollback')"
			tx.query.sync tx, "SELECT fail"

		queryUtils.doInTransaction conn, (tx) ->
			tx.query.sync tx, "INSERT INTO test_table VALUES (5, 'one more thing')"
		test.strictEqual this.count(), 3

