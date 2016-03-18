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

assert = require('chai').assert
requireCovered = require '../require-covered.coffee'
game = requireCovered __dirname, '../lib/game.coffee'
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


mocha = (func) ->
	return (done) ->
		sync func, (error, result) ->
			done(error)


insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) "+
	      "VALUES (#{values.map (v,i) -> '$'+(i+1)+(if v? and typeof v is 'object' then '::json' else '')})",
		values.map((v) -> if v? and typeof v is 'object' then JSON.stringify(v) else v)


exports.beforeEach = mocha ->
	unless _conn?
		_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
		mg.migrate.sync mg, _conn
	conn = transaction(_conn)
	query = queryUtils.getFor conn

exports.afterEach = mocha ->
	conn.rollback.sync(conn)


exports.game = {}


exports.game.getInitialLocation =
	'good test': mocha ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

		loc = game.getInitialLocation conn
		assert.strictEqual loc.id, 2, 'should return id of initial location'
		assert.instanceOf loc.ways, Array, 'should return parsed ways from location'

	'bad test': mocha ->
		insert 'locations', id: 1
		insert 'locations', id: 2
		insert 'locations', id: 3

		assert.throws(
			-> game.getInitialLocation conn
			Error, null,
			'should return error if initial location is not defined'
		)

	'ambiguous test': mocha ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3, initial: 1
		insert 'locations', id: 4

		assert.throws(
			-> game.getInitialLocation conn
			Error, null,
			'should return error if there is more than one initial location'
		)


exports.game.getCharacterLocationId =
	'valid data': mocha ->
		insert 'characters', id: 1, 'location': 3
		insert 'characters', id: 2, 'location': 1

		id1 = game.getCharacterLocationId.sync(null, conn, 1)
		id2 = game.getCharacterLocationId.sync(null, conn, 2)
		assert.strictEqual id1, 3, "should return user's location id"
		assert.strictEqual id2, 1, "should return user's location id"

	'wrong character id': mocha ->
		assert.throws(
			-> game.getCharacterLocationId.sync(null, conn, -1)
			Error, null,
			'should fail on wrong id'
		)


exports.game.getCharacterLocation =
	beforeEach: mocha ->
		insert 'characters', id: 1, location: 3

	'valid data': mocha ->
		insert 'locations', id: 3, area: 5, title: 'The Location', ways:
			[{target:7, text:'Left'}, {target:8, text:'Forward'}, {target:9, text:'Right'}]

		loc = game.getCharacterLocation.sync(null, conn, 1)
		assert.strictEqual loc.id, 3, "should return user's location id"
		assert.deepEqual loc.ways, [
				{ target: 7, text: 'Left' }
				{ target: 8, text: 'Forward' }
				{ target: 9, text: 'Right' }
			], 'should return ways from location'

	'wrong character id': mocha ->
		assert.throws(
			-> game.getCharacterLocation.sync null, conn, -1
			Error, null,
			'should fail on wrong id'
		)

	'wrong locid': mocha ->
		insert 'locations', id: 1, area: 5

		assert.throws(
			-> game.getCharacterLocation.sync null, conn, 1
			Error, null,
			'should fail if user.location is wrong'
		)


exports.game.getCharacterArea =
	beforeEach: mocha ->
		insert 'characters', id: 1, location: 3

	'usual test': mocha ->
		insert 'locations', id: 3, area: 5, title: 'The Location'
		insert 'areas', id: 5, title: 'London'
		area = game.getCharacterArea.sync null, conn, 1

		assert.strictEqual area.id, 5, "should return user's area id"
		assert.strictEqual area.title, 'London', "should return user's area name"

	'wrong user id': mocha ->
		assert.throws(
			-> game.getCharacterArea.sync null, conn, -1
			Error, null,
			'should fail on wrong id'
		)


exports.game.isTherePathForCharacterToLocation = mocha ->
	insert 'characters', id: 1, location: 1
	insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
	insert 'locations', id: 2

	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 2
	assert.strictEqual can, true, "should return true if path exists"

	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
	assert.strictEqual can, false, "should return false if already on this location"

	game.changeLocation.sync null, conn, 1, 2
	can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
	assert.strictEqual can, false, "should return false if path doesn't exist"
