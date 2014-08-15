config = require '../config.js'
sync = require 'sync'
anyDB = require 'any-db'
queryUtils = require '../lib/query_utils'
conn = null
query = null

exports.setUp = (->
	unless conn?
		conn = anyDB.createConnection(config.DATABASE_URL_TEST)
		query = queryUtils.getFor conn
		conn.query.sync conn, 'DROP TABLE IF EXISTS test_table'
		conn.query.sync conn, 'CREATE TABLE test_table (id INT, data TEXT)'
		conn.query.sync conn, "INSERT INTO test_table (id, data) VALUES (1, 'first')"
		conn.query.sync conn, "INSERT INTO test_table (id, data) VALUES (2, 'second')"
).async()


exports.itself = (test) ->
	res = query "INSERT INTO test_table (id, data) VALUES (3, 'third')"
	count = +conn.query.sync(conn, "SELECT count(*) FROM test_table").rows[0].count
	
	test.strictEqual count, 3, 'should perform query'
	test.strictEqual res, undefined, 'should not return anything'
	
	query "DELETE FROM test_table WHERE id = 3"
	test.done()


exports.all = (test) ->
	rows = query.all 'SELECT * FROM test_table ORDER BY id'
	test.deepEqual rows, [
		{id: 1, data: 'first'}
		{id: 2, data: 'second'}
	], 'should return rows from query'
	test.done()


exports.row = (test) ->
	row = query.row 'SELECT * FROM test_table WHERE id = 1'
	test.deepEqual row, {id: 1, data: 'first'}, 'should return the first and only row from query'
	
	test.throws (->
		query.row 'SELECT * FROM test_table'
	), Error, 'should throw error if more than one row returned'
	
	test.throws (->
		query.row 'SELECT * FROM test_table WHERE id = 3'
	), Error, 'should throw error if no rows returned'
	test.done()

exports.val = (test) ->
	data = query.val 'SELECT data FROM test_table WHERE id = 2'
	test.deepEqual data, 'second', 'should return the first and only value from the first and only row'
	
	test.throws (->
		query.val 'SELECT id, data FROM test_table WHERE id = 2'
	), Error, 'should throw error if more than one value returned'
	
	test.throws (->
		query.val 'SELECT * FROM test_table'
	), Error, 'should throw error if more than one row returned'
	
	test.throws (->
		query.val 'SELECT * FROM test_table WHERE id = 3'
	), Error, 'should throw error if no rows returned'
	test.done()
