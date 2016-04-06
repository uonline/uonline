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

NS = 'user'; exports[NS] = {}  # namespace
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
sync = require 'sync'
sugar = require 'sugar'

mg = require '../lib/migration.coffee'
queryUtils = require '../lib/query_utils.coffee'

users = requireCovered __dirname, '../lib/user.coffee'

_conn = null
conn = null
query = null


insert = (table, fields) ->
	queryUtils.unsafeInsert conn, table, fields


exports[NS].before = t ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	mg.migrate.sync mg, _conn

exports[NS].beforeEach = t ->
	conn = transaction(_conn, autoRollback: false)
	query = queryUtils.getFor conn

exports[NS].afterEach = t ->
	conn.rollback.sync(conn)


exports[NS].userExists =
	beforeEach: t ->
		query 'INSERT INTO uniusers (username) VALUES ( $1 )', ['Sauron']
		this.exists = (name) ->
			users.userExists.sync null, conn, name

	'should return true if user exists': t ->
		test.isTrue this.exists('Sauron')
		test.isFalse this.exists('Sauron2')

	'should ignore capitalization': t ->
		test.isTrue this.exists('SAURON')
		test.isTrue this.exists('sauron')


exports[NS].idExists =
	beforeEach: t ->
		query 'INSERT INTO uniusers (id) VALUES ( $1 )', [114]

	'should return if user exists': t ->
		test.isTrue users.idExists.sync(null, conn, 114)
		test.isFalse users.idExists.sync(null, conn, 9000)


exports[NS].sessionExists =
	beforeEach: t ->
		query "INSERT INTO uniusers (sessid) VALUES ('someid')"

	'should return if sessid exists': t ->
		test.isTrue users.sessionExists.sync(null, conn, 'someid')
		test.isFalse users.sessionExists.sync(null, conn, 'wrongid')


exports[NS].sessionInfoRefreshing =
	beforeEach: t ->
		insert 'characters', id: 5, player: 8
		insert 'uniusers',
			id: 8, username: 'user0', character_id: 5,
			permissions: 'admin', sessid: 'expiredid', sess_time: 1.hourAgo()

		this.testingProps = 'id loggedIn username isAdmin character_id'.split(' ')
		this.sessTime = (id=8) -> new Date(query.val('SELECT sess_time FROM uniusers WHERE id = $1', [id]))

	'session should not be active if expired': t ->
		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { loggedIn: false }

	'session expire time should not be updated if expired': t ->
		timeBefore = this.sessTime()
		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual res, { loggedIn: false }
		test.strictEqual this.sessTime().valueOf(), timeBefore.valueOf()

	'session should be active if not expired and user data should be returned': t ->
		query "UPDATE uniusers SET sessid = 'someid'"
		timeBefore = this.sessTime()

		res = users.sessionInfoRefreshing.sync null, conn, 'someid', 7200, false
		test.deepEqual Object.select(res, this.testingProps), {
			id: 8
			loggedIn: true
			username: 'user0'
			isAdmin: true
			character_id: 5
		}

		timeAfter = this.sessTime()
		test.isBelow timeBefore, timeAfter, 'should update session timestamp'

	'should not fail on empty sessid': t ->
		res = users.sessionInfoRefreshing.sync null, conn, undefined, 7200, false
		test.deepEqual res, { loggedIn: false }

	'should return admin: false if user is not admin': t ->
		insert 'characters', id: 6, player: 99
		insert 'uniusers',
			id: 99, username: 'user1', character_id: 6,
			permissions: 'user', sessid: 'otherid', sess_time: 1.hourAgo()

		res = users.sessionInfoRefreshing.sync null, conn, 'otherid', 7200, false
		test.deepEqual Object.select(res, this.testingProps), {
			id: 99
			loggedIn: true
			username: "user1"
			isAdmin: false
			character_id: 6
		}

	'when async flag is set':
		beforeEach: t ->
			insert 'uniusers',
				id: 112, username: '112', character_id: 6,
				permissions: 'admin', sessid: '123456', sess_time: 1.hourAgo()

		'should update session timestamp': t ->
			timeBefore = this.sessTime(112)
			users.sessionInfoRefreshing.sync null, conn, '123456', 7200, true
			sync.sleep 100
			timeAfter = this.sessTime(112)

			test.ok timeBefore < timeAfter

		'should tell about errors via console.error': t ->
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


exports[NS].getUser = new ->
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
		isAdmin: true

	@beforeEach = t ->
		insert 'uniusers', Object.reject(props, 'isAdmin')
		insert 'characters', id: 4, player: 8

	[
		{val: 8,       res: props, msg: 'user attributes by id'}
		{val: 'user0', res: props, msg: 'user attributes by name'}
		{val: 123,     res: null,  msg: 'null if id is wrong'}
		{val: 'user1', res: null,  msg: 'null if name is wrong'}
	].forEach (param) =>
		@["should return #{param.msg}"] = t ->
			user = users.getUser.sync null, conn, param.val
			test.deepEqual user, param.res


exports[NS].generateSessId =
	'should generate uniq sessids': t ->
		_createSalt = users.createSalt
		i = 0
		users.createSalt = (len) ->
			'someid' + (++i)

		query "INSERT INTO uniusers (sessid) VALUES ('someid1')"
		query "INSERT INTO uniusers (sessid) VALUES ('someid2')"
		sessid = users.generateSessId.sync users, conn, 16

		users.createSalt = _createSalt
		test.strictEqual sessid, 'someid3', 'sessid should be unique'


exports[NS].idBySession =
	'should return correct user id': t ->
		query "INSERT INTO uniusers ( id, sessid ) VALUES ( 3, 'someid' )"
		userid = users.idBySession.sync null, conn, "someid"
		test.strictEqual userid, 3

	'should return error on wrong sessid': t ->
		test.throws(
			-> users.idBySession.sync null, conn, 'someid'
			Error, "wrong user's id"
		)


exports[NS].closeSession =
	beforeEach: t ->
		query "INSERT INTO uniusers ( sessid, sess_time ) VALUES ( 'someid', NOW() )"
		users.closeSession.sync null, conn, 'someid'

	'should expire session': t ->
		refr = users.sessionInfoRefreshing.sync null, conn, 'someid', 3600
		test.isFalse refr.loggedIn

	'should not fail with empty sessid': t ->
		warn1 = users.closeSession.sync null, conn, undefined
		test.strictEqual warn1, 'Not closing: empty sessid'


exports[NS].createSalt =
	'should keep specified length': ->
		for len in [0, 1, 2, 5, 10, 20, 50]
			test.strictEqual users.createSalt(len).length, len

	'should use printable characters': t ->
		for i in [0..10]
			test.match users.createSalt(10), /^[a-zA-Z0-9]+$/


exports[NS].registerUser =
	'should register correct user': t ->
		query 'INSERT INTO locations (id, initial) VALUES (2, 1)'

		#TODO: check return value
		users.registerUser.sync null, conn, 'TheUser', 'password', 'admin'
		user = query.row 'SELECT * FROM uniusers'

		test.isAbove user.salt.length, 0, 'should generate salt'
		test.isAbove user.hash.length, 0, 'should generate hash'
		test.isAbove user.sessid.length, 0, 'should generate sessid'
		test.closeTo +user.reg_time, Date.now(), 1000, 'should set registration time to (almost) current time'
		test.closeTo +user.sess_time, Date.now(), 1000, 'should set session timestamp to (almost) current time'
		test.strictEqual user.permissions, 'admin', 'should set specified permissions'
		test.isNull user.character_id, null, 'should not assign character'

		count = +query.val 'SELECT count(*) FROM characters WHERE player = $1', [user.id]
		test.strictEqual count, 0, 'should not create character now'

	'should fail if user exists': t ->
		insert 'uniusers', username: 'TheUser'
		test.throws(
			-> users.registerUser.sync null, conn, 'TheUser', 'password', 1
			Error, 'user already exists'
		)


exports[NS].accessGranted = new ->
	@beforeEach = t ->
		query 'INSERT INTO locations (id, initial) VALUES (2, 1)'
		users.registerUser.sync null, conn, 'TheUser', 'password', 'user'

	[
		{name:'TheUser',   pass:'password',  ok:true,  msg:'should return true for valid data'}
		{name:'WrongUser', pass:'password',  ok:false, msg:'should return false if user does not exist'}
		{name:'WrongUser', pass:'wrongpass', ok:false, msg:'should return false if password is wrong'}
		{name:'THEUSER',   pass:'password',  ok:true,  msg:'should ignore capitalization'}
		{name:'theuser',   pass:'password',  ok:true,  msg:'should ignore capitalization (2)'}
	].forEach ({name, pass, ok, msg}) =>
		@[msg] = t ->
			granted = users.accessGranted.sync null, conn, name, pass
			test.strictEqual granted, ok


exports[NS].createSession =
	beforeEach: t ->
		insert 'locations', id: 2, initial: 1
		users.registerUser.sync null, conn, 'Мохнатый Ангел', 'password', 'user'

	'should change sessid and update session timestamp': ->
		user0 = query.row 'SELECT sessid FROM uniusers'
		users.createSession.sync null, conn, 'МОХНАТЫЙ ангел'
		user1 = query.row 'SELECT sessid, sess_time FROM uniusers'

		test.ok user0.sessid isnt user1.sessid, 'should change sessid'
		test.ok user1.sess_time.getTime() > Date.now() - 60000, 'should update session timestamp'
