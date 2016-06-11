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

dbPool = null
db = null

mg = ask 'lib/migration'

Account = askCovered 'domain/account/pg'
account = null


exports[NS].before = async ->
	dbPool = (await ask('storage').spawn(config.storage)).pgTest
	db = await dbPool.connect()
	#await mg.migrate(_conn)
	account = new Account(db)

exports[NS].beforeEach = async ->
	await db.none 'BEGIN'
	await db.none 'CREATE TABLE account (id SERIAL, name TEXT)'

exports[NS].afterEach = async ->
	await db.none 'ROLLBACK'

exports[NS].after = async ->
	db.done()


exports[NS].search =
	beforeEach: async ->
		await db.none 'INSERT INTO account (name) VALUES ($1)', 'Sauron'
		@user = { id: 1, name: 'Sauron' }

	existsName:
		'should return true if user exists': async ->
			test.isTrue (await account.existsName 'Sauron')
			test.isFalse (await account.existsName 'Sauron2')

		'should ignore capitalization': async ->
			test.isTrue (await account.existsName 'SAURON')
			test.isTrue (await account.existsName 'sauron')

	byName:
		'should return user data if user exists': async ->
			test.deepEqual (await account.byName 'Sauron'), @user

		'should return null if user does not exist': async ->
			test.isNull (await account.byName 'Sauron2')

		'should ignore capitalization': async ->
			test.deepEqual (await account.byName 'SAURON'), @user
			test.deepEqual (await account.byName 'sauron'), @user
