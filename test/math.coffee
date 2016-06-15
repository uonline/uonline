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

NS = 'math'; exports[NS] = {}  # namespace
{async, await} = require 'asyncawait'

ask = require 'require-r'
{test, askCovered, config} = ask 'lib/test-utils.coffee'
AccountPG = ask 'domain/account/pg'
math = askCovered 'lib/math.coffee'

dbPool = null
db = null


exports[NS].before = async ->
	dbPool = (await ask('storage').spawn(config.storage)).pgTest
	db = await dbPool.connect()

exports[NS].beforeEach = async ->
	await db.none 'BEGIN'
	await db.none 'CREATE TABLE account (sessid TEXT)'

exports[NS].afterEach = async ->
	await db.none 'ROLLBACK'

exports[NS].after = async ->
	db.done()

exports[NS].ap =
	'should return n-th number in arithmetical progression': ->
		test.strictEqual math.ap(1,2,3), 5
		test.strictEqual math.ap(3,6,9), 153


exports[NS].createSalt =
	'should keep specified length': ->
		for len in [0, 1, 2, 5, 10, 20, 50]
			test.strictEqual math.createSalt(len).length, len

	'should use printable characters': async ->
		for i in [0..10]
			test.match math.createSalt(10), /^[a-zA-Z0-9]+$/


exports[NS].generateSessId =
	'should generate uniq sessids': async ->
		_createSalt = math.createSalt
		i = 0
		math.createSalt = (len) ->
			'someid' + (++i)

		await db.none "INSERT INTO account (sessid) VALUES ('someid1')"
		await db.none "INSERT INTO account (sessid) VALUES ('someid2')"
		sessid = await math.generateSessId new AccountPG(db), 16

		math.createSalt = _createSalt
		test.strictEqual sessid, 'someid3', 'sessid should be unique'
