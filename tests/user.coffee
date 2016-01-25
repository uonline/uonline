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
users = requireCovered __dirname, '../lib/user.coffee'
config = require '../config'
mg = require '../lib/migration'
sync = require 'sync'
anyDB = require 'any-db'
transaction = require 'any-db-transaction'
queryUtils = require '../lib/query_utils'
sugar = require 'sugar'
_conn = null
conn = null
query = null


clearTables = ->
	query 'TRUNCATE ' + [].join.call(arguments, ', ')

#TODO: to utils
insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) VALUES (#{values.map (_,i) -> '$'+(i+1)})", values


exports.setUp = (->
	unless _conn?
		_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
		mg.migrate.sync mg, _conn
	conn = transaction(_conn)
	query = queryUtils.getFor conn
).async()

exports.tearDown = (->
	conn.rollback.sync(conn)
).async()


exports.userExists = (test) ->
	userExists = (name) ->
		users.userExists.sync null, conn, name

#	test.throws(
#		-> userExists 'Sauron'
#		Error
#		'should fail on nonexistent table'
#	)

	clearTables 'uniusers'
	query 'INSERT INTO uniusers (username) VALUES ( $1 )', ['Sauron']

	test.strictEqual userExists('Sauron'), true, 'should return true if user exists'
	test.strictEqual userExists('SAURON'), true, 'should ignore capitalization'
	test.strictEqual userExists('sauron'), true, 'should ignore capitalization'

	query 'TRUNCATE uniusers'
	test.strictEqual userExists('Sauron'), false, 'should return false if user does not exist'
	test.done()


exports.idExists = (test) ->
	clearTables 'uniusers'
	query 'INSERT INTO uniusers (id) VALUES ( $1 )', [114]

	test.strictEqual users.idExists.sync(null, conn, 114), true, 'should return true when user exists'
	test.strictEqual users.idExists.sync(null, conn, 9000), false, 'should return false when user does not exist'
	test.done()


exports.sessionExists = (test) ->
	clearTables 'uniusers'
	query "INSERT INTO uniusers (sessid) VALUES ('someid')"

	exists = users.sessionExists.sync(null, conn, 'someid')
	test.strictEqual exists, true, 'should return true when sessid exists'

	exists = users.sessionExists.sync(null, conn, 'wrongid')
	test.strictEqual exists, false, 'should return false when sessid does not exist'
	test.done()


exports.sessionInfoRefreshing =
	'usual': (test) ->
		clearTables 'characters', 'uniusers'
		insert 'characters', id: 5, player: 8
		insert 'uniusers',
			id: 8, username: 'user0', character_id: 5,
			permissions: 'admin', sessid: 'expiredid', sess_time: 1.hourAgo()

		testingProps = 'id loggedIn username isAdmin character_id'.split(' ')


		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { loggedIn: false },
			'session should not be active if expired'

		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { loggedIn: false },
			'session expire time should not be updated if expired'


		query "UPDATE uniusers SET sessid = 'someid'"

		timeBefore = new Date(query.val 'SELECT sess_time FROM uniusers')

		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual Object.select(res, testingProps), {
			id: 8
			loggedIn: true
			username: 'user0'
			isAdmin: true
			character_id: 5
		}, 'session should be active if not expired and user data should be returned'

		timeAfter = new Date(query.val 'SELECT sess_time FROM uniusers')
		test.ok timeBefore < timeAfter, 'should update session timestamp'

		res = users.sessionInfoRefreshing.sync null, conn, undefined, 7200, false
		test.deepEqual res, { loggedIn: false }, 'should not fail on empty sessid'


		insert 'characters', id: 6, player: 99
		insert 'uniusers',
			id: 99, username: 'user1', character_id: 6,
			permissions: 'user', sessid: 'otherid', sess_time: 1.hourAgo()

		res = users.sessionInfoRefreshing.sync null, conn, 'otherid', 7200, false
		test.deepEqual Object.select(res, testingProps), {
			id: 99
			loggedIn: true
			username: "user1"
			isAdmin: false
			character_id: 6
		}, 'should return admin: false if user is not admin'
		test.done()

	'async update': (test) ->
		insert 'uniusers',
			id: 112, username: '112', character_id: 6,
			permissions: 'admin', sessid: '123456', sess_time: 1.hourAgo()

		timeBefore = new Date(query.val('SELECT sess_time FROM uniusers WHERE id = 112'))
		users.sessionInfoRefreshing.sync null, conn, '123456', 7200, true
		sync.sleep 100
		timeAfter = new Date(query.val('SELECT sess_time FROM uniusers WHERE id = 112'))

		test.ok timeBefore < timeAfter, 'should update session timestamp with asyncUpdate'

		# test fail
		q = conn.query
		conn.query = (sql, args, callback) ->
			if sql.match /UPDATE uniusers/
				callback(new Error('test error'), null)
			else
				q.apply(conn, arguments)

		errCalled = false
		errlog = console.error
		console.error = -> errCalled = true

		users.sessionInfoRefreshing.sync null, conn, '123456', 7200, true
		sync.sleep 100
		test.ok errCalled, 'should tell about error'

		conn.query = q
		console.error = errlog
		test.done()


exports.getUser = (test) ->
	props =
		id: 8
		username: 'user0'
		mail: 'test@mail.com'
		reg_time: new Date '2015-01-02 15:03:04'
		permissions: 'admin'
		sessid: 'sessid'
		sess_time: new Date '2015-01-02 15:03:44'
		salt: 'salt'
		hash: 'hash'
		character_id: 4

	clearTables 'characters', 'uniusers'
	insert 'uniusers', props
	insert 'characters', id: 4, player: 8

	Object.merge props, isAdmin: true

	[
		{val: 8,       res: props, msg: 'user attributes by id'}
		{val: 'user0', res: props, msg: 'user attributes by name'}
		{val: 123,     res: null,  msg: 'null if id is wrong'}
		{val: 'user1', res: null,  msg: 'null if name is wrong'}
	].forEach (param) ->
		user = users.getUser.sync null, conn, param.val
		test.deepEqual user, param.res, "should return #{param.msg}"

	test.done()


exports.generateSessId = (test) ->
	_createSalt = users.createSalt
	i = 0
	users.createSalt = (len) ->
		'someid' + (++i)

	clearTables 'uniusers'
	query "INSERT INTO uniusers (sessid) VALUES ('someid1')"
	query "INSERT INTO uniusers (sessid) VALUES ('someid2')"
	sessid = users.generateSessId.sync users, conn, 16

	users.createSalt = _createSalt
	test.strictEqual sessid, 'someid3', 'sessid should be unique'
	test.done()


exports.idBySession =
	testNoErrors: (test) ->
		clearTables 'uniusers'
		query "INSERT INTO uniusers ( id, sessid ) VALUES ( 3, 'someid' )"
		userid = users.idBySession.sync null, conn, "someid"
		test.strictEqual userid, 3, 'should return correct user id'
		test.done()

	testWrongSessid: (test) ->
		clearTables 'uniusers'
		test.throws(
			-> users.idBySession.sync null, conn, 'someid'
			Error
			'should return error on wrong sessid'
		)
		test.done()


exports.closeSession = (test) ->
	clearTables 'uniusers'
	query "INSERT INTO uniusers ( sessid, sess_time ) VALUES ( 'someid', NOW() )"
	users.closeSession.sync null, conn, 'someid'
	refr = users.sessionInfoRefreshing.sync null, conn, 'someid', 3600
	warn1 = users.closeSession.sync null, conn, undefined

	test.strictEqual refr.loggedIn, false, 'session should have expired'
	test.strictEqual warn1, 'Not closing: empty sessid', 'should not fail with empty sessid'
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
	clearTables 'uniusers', 'locations', 'monsters', 'monster_prototypes', 'characters'
	query 'INSERT INTO locations (id, initial) VALUES (2, 1)'

	#TODO: check return value
	users.registerUser.sync null, conn, 'TheUser', 'password', 'admin'
	user = query.row 'SELECT * FROM uniusers'

	test.ok user.salt.length > 0, 'should generate salt'
	test.ok user.hash.length > 0, 'should generate hash'
	test.ok user.sessid.length > 0, 'should generate sessid'
	test.ok Math.abs(user.reg_time - new Date()) < 1000, 'should set registration time to (almost) current time'
	test.ok Math.abs(user.sess_time - new Date()) < 1000, 'should set session timestamp to (almost) current time'
	test.strictEqual user.permissions, 'admin', 'should set specified permissions'
	test.strictEqual user.character_id, null, 'should not assign character'

	count = +query.val 'SELECT count(*) FROM characters WHERE player = $1', [user.id]
	test.strictEqual count, 0, 'should not create character now'

	test.throws(
		-> users.registerUser.sync null, conn, 'TheUser', 'password', 1
		Error
		'should fail if user exists'
	)
	test.done()


exports.accessGranted = (test) ->
	clearTables 'uniusers', 'characters', 'locations'
	query 'INSERT INTO locations (id, initial) VALUES (2, 1)'
	users.registerUser.sync null, conn, 'TheUser', 'password', 'user'

	[
		{name:'TheUser',   pass:'password',  ok:true,  msg:'should return true for valid data'}
		{name:'WrongUser', pass:'password',  ok:false, msg:'should return false if user does not exist'}
		{name:'WrongUser', pass:'wrongpass', ok:false, msg:'should return false if password is wrong'}
		{name:'THEUSER',   pass:'password',  ok:true,  msg:'should ignore capitalization'}
		{name:'theuser',   pass:'password',  ok:true,  msg:'should ignore capitalization (2)'}
	].forEach (t) ->
		granted = users.accessGranted.sync null, conn, t.name, t.pass
		test.strictEqual granted, t.ok, t.msg
	test.done()


exports.createSession = (test) ->
	clearTables 'uniusers', 'locations', 'characters'
	query 'INSERT INTO locations (id, initial) VALUES (2, 1)'
	users.registerUser.sync null, conn, 'Мохнатый Ангел', 'password', 'user'
	user0 = query.row 'SELECT sessid FROM uniusers'
	users.createSession.sync null, conn, 'МОХНАТЫЙ ангел'
	user1 = query.row 'SELECT sessid, sess_time FROM uniusers'

	test.ok user0.sessid isnt user1.sessid, 'should change sessid'
	test.ok user1.sess_time.getTime() > Date.now() - 60000, 'should update session timestamp'
	test.done()

