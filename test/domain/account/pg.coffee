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


NS = 'domain/account/pg'; exports[NS] = {}  # namespace
ask = require 'require-r'
{test, requireCovered, askCovered, config} = ask 'lib/test-utils.coffee'
{async, await} = require 'asyncawait'
require 'sugar'

db = null

Account = askCovered 'domain/account/pg'
account = null


exports.NS = NS

exports.useDB = (_db) ->
	db = _db
	account = new Account(db)

exports[NS].beforeEach = async ->
	await db.none 'BEGIN'
	await db.none 'CREATE TABLE account (id SERIAL, name TEXT, password_salt TEXT, password_hash TEXT, sessid TEXT, reg_time TIMESTAMPTZ, sess_time TIMESTAMPTZ, permissions TEXT, character_id INT)'

exports[NS].afterEach = async ->
	await db.none 'ROLLBACK'


exports[NS].search =
	beforeEach: async ->
		await db.none 'INSERT INTO account (id, name) VALUES (1, $1)', 'Sauron'
		await db.none 'INSERT INTO account (id, sessid) VALUES (2, $1)', 'someid'
		@acc = await account.byName 'Sauron'

	existsID:
		'should return true if id exists': async ->
			test.isTrue (await account.existsID 1)
			test.isFalse (await account.existsID 3)

	byID:
		'should return account data if exists': async ->
			test.deepEqual (await account.byID 1), @acc

		'should return null if does not exist': async ->
			test.isNull (await account.byID 4)

	existsName:
		'should return true if user exists': async ->
			test.isTrue (await account.existsName 'Sauron')
			test.isFalse (await account.existsName 'Sauron2')

		'should ignore capitalization': async ->
			test.isTrue (await account.existsName 'SAURON')
			test.isTrue (await account.existsName 'sauron')

	byName:
		'should return account data if account exists': async ->
			test.deepEqual (await account.byName 'Sauron'), @acc

		'should return null if user does not exist': async ->
			test.isNull (await account.byName 'Sauron2')

		'should ignore capitalization': async ->
			test.deepEqual (await account.byName 'SAURON'), @acc
			test.deepEqual (await account.byName 'sauron'), @acc

	existsSessid:
		'should return if sessid exists': async ->
			test.isTrue await account.existsSessid('someid')
			test.isFalse await account.existsSessid('wrongid')


exports[NS].create =
	'should register correct user': async ->
		res = await account.create 'TheUser', 'password', 'admin'
		acc = await db.one 'SELECT * FROM account'

		test.strictEqual res.id, acc.id, 'should return new account id'
		test.strictEqual res.sessid, acc.sessid, 'should return new account sessid'

		test.isAbove acc.password_salt.length, 0, 'should generate salt'
		test.isAbove acc.password_hash.length, 0, 'should generate hash'
		test.isAbove acc.sessid.length, 0, 'should generate sessid'
		test.closeTo +acc.reg_time, Date.now(), 1000, 'should set registration time to (almost) current time'
		test.closeTo +acc.sess_time, Date.now(), 1000, 'should set session timestamp to (almost) current time'
		test.strictEqual acc.permissions, 'admin', 'should set specified permissions'
		test.isNull acc.character_id, 'should not assign character'

	'should fail if user exists': async ->
		await db.none "INSERT INTO account (name) VALUES ('TheUser')"
		await test.isRejected account.create('TheUser', 'password', 1), /user already exists/


exports[NS].accessGranted = new ->
	@beforeEach = async ->
		await account.create 'TheUser', 'password', 'user'

	[
		{name:'TheUser',   pass:'password',  ok:true,  msg:'should return true for valid data'}
		{name:'WrongUser', pass:'password',  ok:false, msg:'should return false if user does not exist'}
		{name:'WrongUser', pass:'wrongpass', ok:false, msg:'should return false if password is wrong'}
		{name:'THEUSER',   pass:'password',  ok:true,  msg:'should ignore capitalization'}
		{name:'theuser',   pass:'password',  ok:true,  msg:'should ignore capitalization (2)'}
	].forEach ({name, pass, ok, msg}) =>
		@[msg] = async ->
			granted = await account.accessGranted name, pass
			test.strictEqual granted, ok


exports[NS].update =
	beforeEach: async ->
		await db.none '''
			INSERT INTO account (id, name, password_salt, password_hash)
			VALUES (1, 'User1', 'salt', 'hash'), (2, 'User2', NULL, NULL)'''
		@acc1 = account.byID 1
		@params = {
			id: 1, name: 'user_1', sessid: 'some_id',
			permissions: 'user', character_id: 1,
			sess_time: new Date().beginningOfDay(), reg_time: new Date().beginningOfMonth(),
			password_salt: 'mewsalt', password_hash: 'newhash',
			extra_param: 'something'
		}

	'should update all except password hash and salt and extra attributes': async ->
		await account.update(@params)
		updated = await account.byID 1

		params = Object.reject(@params, 'extra_param')
		params.password_salt = 'salt'
		params.password_hash = 'hash'
		test.deepEqual updated, params

	'should not affect other accounts': async ->
		await account.update(@params)
		test.isTrue await account.existsName 'User2'


exports[NS].updatePassword =
	beforeEach: async ->
		await account.create 'TheUser', 'passwd', 'user'
		@account = await db.one 'SELECT * FROM account'

	'should update hash and salt': async ->
		await account.updatePassword @account.id, 'newpasswd'
		updated = await db.one 'SELECT * FROM account'
		test.notStrictEqual @account.password_salt, updated.password_salt
		test.notStrictEqual @account.password_hash, updated.password_hash
		test.isTrue (await account.accessGranted 'TheUser', 'newpasswd')

	'should not affet other users': async ->
		await account.create 'Admin', 'admin', 'admin'
		await account.updatePassword @account.id, 'newpasswd'
		test.isTrue (await account.accessGranted 'Admin', 'admin')

	'should do nothing if id is wrong': async ->
		await account.updatePassword -1, 'newpasswd'
		test.isTrue (await account.accessGranted 'TheUser', 'passwd')


exports[NS].remove =
	beforeEach: async ->
		await db.none "INSERT INTO account (id, name) VALUES (1, 'User1'), (2, 'User2')"
		@acc1 = await account.byName('user1')

	'should remove account by id': async ->
		await account.remove @acc1.id
		test.isFalse await account.existsName 'User1'
		test.isTrue await account.existsName 'User2'
