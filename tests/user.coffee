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
users = require '../lib-cov/user'
mg = require '../lib/migration'
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

migrateTables = ->
	args = (i for i in arguments)
	mg.migrate.sync mg, conn, tables: args


exports.setUp = (->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	query 'DROP TABLE IF EXISTS revision, uniusers, locations'
	query 'DROP TYPE IF EXISTS permission_kind'
).async()

exports.tearDown = (->
	conn.end()
).async()


exports.userExists = (test) ->
	userExists = (name) ->
		users.userExists.sync null, conn, name

#	test.throws(
#		-> userExists 'Sauron'
#		Error
#		'should fail on nonexistent table'
#	)

	migrateTables 'permission_kind', 'uniusers'
	query 'INSERT INTO uniusers (username) VALUES ( $1 )', ['Sauron']
	
	test.strictEqual userExists('Sauron'), true, 'should return true if user exists'
	test.strictEqual userExists('SAURON'), true, 'should ignore capitalization'
	test.strictEqual userExists('sauron'), true, 'should ignore capitalization'
	
	query 'TRUNCATE uniusers'
	test.strictEqual userExists('Sauron'), false, 'should return false if user does not exist'
	test.done()


exports.idExists = (test) ->
	migrateTables 'permission_kind', 'uniusers'
	query 'INSERT INTO uniusers (id) VALUES ( $1 )', [114]
	
	test.strictEqual users.idExists.sync(null, conn, 114), true, 'should return true when user exists'
	test.strictEqual users.idExists.sync(null, conn, 9000), false, 'should return false when user does not exist'
	test.done()


exports.sessionExists =
	testNoErrors: (test) ->
		migrateTables 'permission_kind', 'uniusers'
		query "INSERT INTO uniusers (sessid) VALUES ('someid')"
		
		exists = users.sessionExists.sync(null, conn, 'someid')
		test.strictEqual exists, true, 'should return true when sessid exists'
		
		exists = users.sessionExists.sync(null, conn, 'wrongid')
		test.strictEqual exists, false, 'should return false when sessid does not exist'
		test.done()

#	testErrors: (test) ->
#		users.sessionExists conn, 'someid', (error, result) ->
#			test.ok error, 'should return error without table'
#			test.done()


exports.sessionInfoRefreshing =
	testNoErrors: (test) ->
		migrateTables 'permission_kind', 'uniusers'
		query "INSERT INTO uniusers " +
			"(id, username, permissions, sessid, sess_time) " +
			"VALUES (8, 'user0', 'admin', 'expiredid', NOW() - INTERVAL '3600 SECOND' )"
		
		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { sessionIsActive: false },
			'session should not be active if expired'
		
		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { sessionIsActive: false },
				'sesson expire time should not be updated if expired'
		
		
		query "UPDATE uniusers SET sessid = 'someid'"
		
		timeBefore = new Date(queryOne('SELECT sess_time FROM uniusers').sess_time)
		
		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, {
			sessionIsActive: true
			username: 'user0'
			admin: true
			userid: 8
		}, 'session should be active if not expired and user data should be returned'
		
		timeAfter = new Date(queryOne('SELECT sess_time FROM uniusers').sess_time)
		test.ok timeBefore < timeAfter, 'should update session timestamp'
		
		res = users.sessionInfoRefreshing.sync null, conn, undefined, 7200, false
		test.deepEqual res, { sessionIsActive: false }, 'should not fail on empty sessid'
		
		
		query "INSERT INTO uniusers " +
			"(id, username, permissions, sessid, sess_time) " +
			"VALUES (99, 'user1', 'user', 'otherid', NOW() + INTERVAL '3600 SECOND' )"
		
		res = users.sessionInfoRefreshing.sync null, conn, 'otherid', 7200, false
		test.deepEqual res, {
			sessionIsActive: true
			username: "user1"
			admin: false
			userid: 99
		}, 'should return admin: false if user is not admin'
		
		
		query "INSERT INTO uniusers " +
			"(id, username, permissions, sessid, sess_time) " +
			"VALUES (112, '112', 'admin', '123456', NOW() - INTERVAL '3600 SECOND' )"
		
		timeBefore = new Date(queryOne('SELECT sess_time FROM uniusers WHERE id = 112').sess_time)
		users.sessionInfoRefreshing.sync null, conn, '123456', 7200, true
		sync.sleep 100
		timeAfter = new Date(queryOne('SELECT sess_time FROM uniusers WHERE id = 112').sess_time)
		
		#test.ok timeBefore < timeAfter, 'should update session timestamp with asyncUpdate'
		test.done()

#	testErrors: (test) ->
#		users.sessionInfoRefreshing conn, 'someid', 0, (error, result) ->
#			test.ok error, 'should return error without table'
#			test.done()


exports.generateSessId =
	testNoErrors: (test) ->
		_createSalt = users.createSalt
		i = 0
		users.createSalt = (len) ->
			'someid' + (++i)

		async.series [
			(callback) ->
				mg.migrate conn, { tables: ['permission_kind', 'uniusers'] }, callback
			(callback) ->
				conn.query "INSERT INTO uniusers (sessid) VALUES ('someid1')", callback
			(callback) ->
				conn.query "INSERT INTO uniusers (sessid) VALUES ('someid2')", callback
			(callback) ->
				users.generateSessId conn, 16, callback
			(callback) ->
				conn.query 'DROP TABLE uniusers', [], callback
		],
		(error, result) ->
			users.createSalt = _createSalt
			test.ifError error
			test.strictEqual result[3], 'someid3', 'sessid should be unique'
			test.done()

	testErrors: (test) ->
		users.generateSessId conn, 16, (error, result) ->
			test.ok error, 'should return error without table'
			test.done()


exports.idBySession =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { tables: ['permission_kind', 'uniusers'] }, callback
			(callback) ->
				conn.query "INSERT INTO uniusers ( id, sessid ) VALUES ( 3, 'someid' )", callback
			(callback) ->
				users.idBySession conn, "someid", callback
		],
		(error, result) ->
			test.ifError error
			test.strictEqual result[2], 3, 'should return correct user id'
			test.done()

	testWrongSessid: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { tables: ['permission_kind', 'uniusers'] }, callback
			(callback) ->
				users.idBySession conn, 'someid', callback
			(callback) ->
				conn.query 'DROP TABLE uniusers', [], callback
		],
		(error, result) ->
			test.ok error, 'should return error on wrong sessid'
			test.done()

	testQueryError: (test) ->
		users.idBySession conn, 'someid', (error, result) ->
			test.ok error, 'should return error without table'
			test.done()


exports.closeSession =
	testNoErrors: (test) ->
		async.series [
			(callback) -> #0
				mg.migrate conn, { tables: ['permission_kind', 'uniusers'] }, callback
			(callback) ->
				conn.query "INSERT INTO uniusers ( sessid, sess_time ) VALUES ( 'someid', NOW() )", [], callback
			(callback) ->
				users.closeSession conn, 'someid', callback
			(callback) ->
				users.sessionInfoRefreshing conn, 'someid', 3600, callback
			(callback) ->
				users.closeSession conn, undefined, callback
		],
		(error, result) ->
			test.ifError error
			test.strictEqual result[3].sessionIsActive, false, 'session should have expired'
			test.strictEqual result[4], 'Not closing: empty sessid', 'should not fail with empty sessid'
			test.done()

	testErrors: (test) ->
		users.closeSession conn, 'someid', (error, result) ->
			test.ok error, 'should return error without table'
			test.done()


exports.createSalt = (test) ->
	salt = users.createSalt(50)
	test.strictEqual salt.length, 50, 'should keep specified length'
	test.ok (/^[a-zA-Z0-9]+$/).test(salt), 'should use printable characters'

	salt = users.createSalt(10)
	test.strictEqual salt.length, 10, 'should keep specified length'
	test.ok (/^[a-zA-Z0-9]+$/).test(salt), 'should use printable characters'

	test.done()


exports.registerUser = (test) ->
	async.series [
		(callback) ->
			mg.migrate conn, { tables: ['permission_kind', 'uniusers', 'locations'] }, callback
		(callback) ->
			conn.query 'INSERT INTO locations (id, initial) VALUES (2, 1)', [], callback
		(callback) ->
			users.registerUser conn, 'TheUser', 'password', 'admin', callback
		(callback) ->
			conn.query 'SELECT * FROM uniusers', callback
	],
	(error, result) ->
		test.ifError error
		test.strictEqual result[3].rows.length, 1, 'should create exactly one user'
		user = result[3].rows[0]
		test.ok user.salt.length > 0, 'should generate salt'
		test.ok user.hash.length > 0, 'should generate hash'
		test.ok user.sessid.length > 0, 'should generate sessid'
		test.ok user.reg_time <= new Date(), 'should not put registration time into future'
		test.ok user.sess_time <= new Date(), 'should not put session timestamp into future'
		test.strictEqual user.location, 2, 'should set location to initial one'
		test.strictEqual user.permissions, 'admin', 'should set specified permissions'
		users.registerUser conn, 'TheUser', 'password', 1, (error, result) ->
			test.ok(!!error, 'should fail if user exists')
			test.done()


exports.accessGranted =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { tables: ['permission_kind', 'uniusers', 'locations'] }, callback
			(callback) ->
				conn.query 'INSERT INTO locations (id, initial) VALUES (2, 1)', callback
			(callback) ->
				users.registerUser conn, 'TheUser', 'password', 'user', callback
			(callback) ->
				users.accessGranted conn, 'TheUser', 'password', callback
			(callback) ->
				users.accessGranted conn, 'WrongUser', 'password', callback
			(callback) ->
				users.accessGranted conn, 'TheUser', 'wrongpass', callback
			(callback) ->
				users.accessGranted conn, 'THEUSER', 'password', callback
			(callback) ->
				users.accessGranted conn, 'theuser', 'password', callback
		], (error, result) ->
			test.ifError error
			test.strictEqual result[3], true, 'should return true for valid data'
			test.strictEqual result[4], false, 'should return false if user does not exist'
			test.strictEqual result[5], false, 'should return false if password is wrong'
			test.strictEqual result[6], true, 'should ignore capitalization'
			test.strictEqual result[7], true, 'should ignore capitalization'
			test.done()

	testErrors: (test) ->
		users.accessGranted conn, 'TheUser', 'password', (error, result) ->
			test.ok error
			test.done()


exports.createSession =
	testNoErrors: (test) ->
		async.series [
			(callback) -> #0
				mg.migrate conn, { tables: ['permission_kind', 'uniusers', 'locations'] }, callback
			(callback) ->
				conn.query 'INSERT INTO locations (id, initial) VALUES (2, 1)', callback
			(callback) ->
				users.registerUser conn, 'Мохнатый Ангел', 'password', 'user', callback
			(callback) ->
				conn.query 'SELECT sessid FROM uniusers', [], callback
			(callback) ->
				users.createSession conn, 'МОХНАТЫЙ ангел', callback
			(callback) -> #5
				conn.query 'SELECT sessid, sess_time FROM uniusers', [], callback
		],
		(error, result) ->
			test.ifError error
			test.ok result[3].rows[0].sessid isnt result[5].rows[0].sessid,
				'should change sessid'
			test.ok result[5].rows[0].sess_time.getTime() > new Date().getTime() - 60000,
				'should update session timestamp'
			test.done()

#	testErrors: (test) ->
#		users.createSession conn, 10101, (error, result) ->
#			test.ok error, 'should crash on wrong sessid'
#			test.done()
