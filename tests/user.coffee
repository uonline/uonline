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
anyDB = require 'any-db'
conn = null


exports.setUp = (done) ->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	conn.query 'DROP TABLE IF EXISTS revision, uniusers, locations', [], done

exports.tearDown = (done) ->
	conn.end()
	done()


exports.userExists = (test) ->
	users.userExists conn, 'Sauron', (error, result) ->
		test.ok !!error, 'should fail on nonexistent table'

	async.series [
		(callback) ->
			mg.migrate conn, { table: 'uniusers' }, callback
		(callback) ->
			conn.query 'INSERT INTO uniusers (username) VALUES ( $1 )', ['Sauron'], callback
		(callback) ->
			users.userExists conn, 'Sauron', callback
		(callback) ->
			users.userExists conn, 'SAURON', callback
		(callback) ->
			users.userExists conn, 'sauron', callback
		(callback) ->
			conn.query 'TRUNCATE uniusers', [], callback
		(callback) ->
			users.userExists conn, 'Sauron', callback
		(callback) ->
			conn.query 'DROP TABLE uniusers', [], callback
	],
	(error, result) ->
		test.ifError error
		test.strictEqual result[2], true, 'should return true if user exists'
		test.strictEqual result[3], true, 'should ignore capitalization'
		test.strictEqual result[4], true, 'should ignore capitalization'
		test.strictEqual result[6], false, 'should return false if user does not exist'
		test.done()


exports.idExists = (test) ->
	async.series [
		(callback) ->
			mg.migrate conn, { table: 'uniusers' }, callback
		(callback) ->
			conn.query 'INSERT INTO uniusers (id) VALUES ( $1 )', [114], callback
		(callback) ->
			users.idExists conn, 114, callback
		(callback) ->
			users.idExists conn, 9000, callback
		(callback) ->
			conn.query 'DROP TABLE uniusers', [], callback
	],
	(error, result) ->
		test.ifError error
		test.strictEqual result[2], true, 'should return true when user exists'
		test.strictEqual result[3], false, 'should return false when user does not exist'
		test.done()


exports.sessionExists =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { table: 'uniusers' }, callback
			(callback) ->
				conn.query "INSERT INTO uniusers (sessid) VALUES ('someid')", callback
			(callback) ->
				users.sessionExists conn, 'someid', callback
			(callback) ->
				users.sessionExists conn, 'wrongid', callback
			(callback) ->
				conn.query 'DROP TABLE uniusers', [], callback
		],
		(error, result) ->
			test.ifError error
			test.strictEqual result[2], true, 'should return true when sessid exists'
			test.strictEqual result[3], false, 'should return false when sessid does not exist'
			test.done()

	testErrors: (test) ->
		users.sessionExists conn, 'someid', (error, result) ->
			test.ok error, 'should return error without table'
			test.done()


exports.sessionInfoRefreshing =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { table: 'uniusers' }, callback
			(callback) ->
				conn.query "INSERT INTO uniusers " +
					"(id, username, permissions, sessid, sess_time) " +
					"VALUES (8, 'user0', $1, 'expiredid', NOW() - INTERVAL '3600 SECOND' )",
					[config.PERMISSIONS_ADMIN], callback
			(callback) ->
				users.sessionInfoRefreshing conn, 'someid', 7200, callback
			(callback) ->
				users.sessionInfoRefreshing conn, 'someid', 7200, callback
			(callback) ->
				conn.query "UPDATE uniusers SET sessid = 'someid'", [], callback
			(callback) -> #5
				conn.query 'SELECT sess_time FROM uniusers', [], callback
			(callback) ->
				users.sessionInfoRefreshing conn, 'someid', 7200, callback
			(callback) ->
				conn.query 'SELECT sess_time FROM uniusers', [], callback
			(callback) ->
				users.sessionInfoRefreshing conn, undefined, 7200, callback
			(callback) ->
				conn.query "INSERT INTO uniusers " +
					"(id, username, permissions, sessid, sess_time) " +
					"VALUES (99, 'user1', $1, 'otherid', NOW() + INTERVAL '3600 SECOND' )",
					[config.PERMISSIONS_USER], callback
			(callback) -> #10
				users.sessionInfoRefreshing conn, 'otherid', 7200, callback
			(callback) ->
				conn.query 'DROP TABLE uniusers', [], callback
		],
		(error, result) ->
			test.ifError error
			test.deepEqual result[2], { sessionIsActive: false },
				'session should not be active if expired'
			test.deepEqual result[3], { sessionIsActive: false },
				'sesson expire time should not be updated if expired'
			test.deepEqual result[6], {
				sessionIsActive: true
				username: 'user0'
				admin: true
				userid: 8
			}, 'session should be active if not expired and user data should be returned'
			test.deepEqual result[8], { sessionIsActive: false }, 'should not fail on empty sessid'
			timeBefore = new Date(result[5].rows[0].sess_time)
			timeAfter = new Date(result[7].rows[0].sess_time)
			test.deepEqual result[10], {
				sessionIsActive: true
				username: "user1"
				admin: false
				userid: 99
			}, 'should return admin: false if user is not admin'
			test.ok timeBefore < timeAfter, 'should update session timestamp'
			test.done()

	testErrors: (test) ->
		users.sessionInfoRefreshing conn, 'someid', 0, (error, result) ->
			test.ok error, 'should return error without table'
			test.done()


exports.generateSessId =
	testNoErrors: (test) ->
		_createSalt = users.createSalt
		i = 0
		users.createSalt = (len) ->
			'someid' + (++i)

		async.series [
			(callback) ->
				mg.migrate conn, { table: 'uniusers' }, callback
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
				mg.migrate conn, { table: 'uniusers' }, callback
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
				mg.migrate conn, { table: 'uniusers' }, callback
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
				mg.migrate conn, { table: 'uniusers' }, callback
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
			mg.migrate conn, { table: 'uniusers' }, callback
		(callback) ->
			mg.migrate conn, { table: 'locations' }, callback
		(callback) ->
			conn.query 'INSERT INTO locations (id, "default") VALUES (2, 1)', [], callback
		(callback) ->
			users.registerUser conn, 'TheUser', 'password', 1, callback
		(callback) ->
			conn.query 'SELECT * FROM uniusers', callback
	],
	(error, result) ->
		test.ifError error
		test.strictEqual result[4].rows.length, 1, 'should create exactly one user'
		user = result[4].rows[0]
		test.ok user.salt.length > 0, 'should generate salt'
		test.ok user.hash.length > 0, 'should generate hash'
		test.ok user.sessid.length > 0, 'should generate sessid'
		test.ok user.reg_time <= new Date(), 'should not put registration time into future'
		test.ok user.sess_time <= new Date(), 'should not put session timestamp into future'
		test.strictEqual user.location, 2, 'should set location to default one'
		test.strictEqual user.permissions, 1, 'should set specified permissions'
		users.registerUser conn, 'TheUser', 'password', 1, (error, result) ->
			test.ok(!!error, 'should fail if user exists')
			test.done()


exports.accessGranted =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				mg.migrate conn, { table: 'uniusers' }, callback
			(callback) ->
				mg.migrate conn, { table: 'locations' }, callback
			(callback) ->
				conn.query 'INSERT INTO locations (id, "default") VALUES (2, 1)', callback
			(callback) ->
				users.registerUser conn, 'TheUser', 'password', 1, callback
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
			test.strictEqual result[4], true, 'should return true for valid data'
			test.strictEqual result[5], false, 'should return false if user does not exist'
			test.strictEqual result[6], false, 'should return false if password is wrong'
			test.strictEqual result[7], true, 'should ignore capitalization'
			test.strictEqual result[8], true, 'should ignore capitalization'
			test.done()

	testErrors: (test) ->
		users.accessGranted conn, 'TheUser', 'password', (error, result) ->
			test.ok error
			test.done()


exports.createSession =
	testNoErrors: (test) ->
		async.series [
			(callback) -> #0
				mg.migrate conn, { table: "uniusers" }, callback
			(callback) ->
				mg.migrate conn, { table: "locations" }, callback
			(callback) ->
				conn.query 'INSERT INTO locations (id, "default") VALUES (2, 1)', callback
			(callback) ->
				users.registerUser conn, 'Мохнатый Ангел', 'password', 1, callback
			(callback) ->
				conn.query 'SELECT sessid FROM uniusers', [], callback
			(callback) -> #5
				users.createSession conn, 'МОХНАТЫЙ ангел', callback
			(callback) ->
				conn.query 'SELECT sessid, sess_time FROM uniusers', [], callback
		],
		(error, result) ->
			test.ifError error
			test.ok result[4].rows[0].sessid isnt result[6].rows[0].sessid,
				'should change sessid'
			test.ok result[6].rows[0].sess_time.getTime() > new Date().getTime() - 60000,
				'should update session timestamp'
			test.done()

	testErrors: (test) ->
		users.createSession conn, 1, (error, result) ->
			test.ok error, 'should not crash if error has occured'
			test.done()
