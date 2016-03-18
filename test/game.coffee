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

test = require('chai').assert
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
		sync func.bind(this), (error, result) ->
			done(error)


insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) "+
	      "VALUES (#{values.map (v,i) -> '$'+(i+1)+(if v? and typeof v is 'object' then '::json' else '')})",
		values.map((v) -> if v? and typeof v is 'object' then JSON.stringify(v) else v)


exports.before = mocha ->
	_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	mg.migrate.sync mg, _conn

exports.beforeEach = mocha ->
	conn = transaction(_conn)
	query = queryUtils.getFor conn

exports.afterEach = mocha ->
	conn.rollback.sync(conn)


exports.game = {}


exports.game.getInitialLocation =
	beforeEach: mocha ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

	'should return id and parsed ways': mocha ->
		loc = game.getInitialLocation conn
		test.strictEqual loc.id, 2, 'should return id of initial location'
		test.instanceOf loc.ways, Array, 'should return parsed ways from location'

	'should return error if initial location is not defined': mocha ->
		query 'UPDATE locations SET initial = 0'
		test.throws(
			-> game.getInitialLocation conn
			Error, null
		)

	'should return error if there is more than one initial location': mocha ->
		query 'UPDATE locations SET initial = 1 WHERE id = 3'
		test.throws(
			-> game.getInitialLocation conn
			Error, null
		)


exports.game.getCharacterLocationId =
	"should return user's location id": mocha ->
		insert 'characters', id: 1, 'location': 3
		insert 'characters', id: 2, 'location': 1
		test.strictEqual game.getCharacterLocationId.sync(null, conn, 1), 3
		test.strictEqual game.getCharacterLocationId.sync(null, conn, 2), 1

	'should fail if character id is wrong': mocha ->
		test.throws(
			-> game.getCharacterLocationId.sync(null, conn, -1)
			Error, null,
		)


exports.game.getCharacterLocation =
	beforeEach: mocha ->
		insert 'characters', id: 1, location: 3

	'should return location id and ways': mocha ->
		ways = [
			{target:7, text:'Left'}
			{target:8, text:'Forward'}
			{target:9, text:'Right'}
		]
		insert 'locations', id: 3, area: 5, title: 'The Location', ways: ways

		loc = game.getCharacterLocation.sync(null, conn, 1)
		test.strictEqual loc.id, 3
		test.deepEqual loc.ways, ways

	'should fail on wrong character id': mocha ->
		test.throws(
			-> game.getCharacterLocation.sync null, conn, -1
			Error, null,
		)

	"should fail if user's location is wrong": mocha ->
		insert 'locations', id: 1, area: 5
		test.throws(
			-> game.getCharacterLocation.sync null, conn, 1
			Error, null,
		)


exports.game.getCharacterArea =
	beforeEach: mocha ->
		insert 'characters', id: 1, location: 3

	"should return user's area id and name": mocha ->
		insert 'locations', id: 3, area: 5, title: 'The Location'
		insert 'areas', id: 5, title: 'London'
		area = game.getCharacterArea.sync null, conn, 1

		test.strictEqual area.id, 5
		test.strictEqual area.title, 'London'

	'should fail on wrong user id': mocha ->
		test.throws(
			-> game.getCharacterArea.sync null, conn, -1
			Error, null,
		)


exports.game.isTherePathForCharacterToLocation =
	beforeEach: mocha ->
		insert 'characters', id: 1, location: 1
		insert 'locations', id: 1, ways: [{target:2, text:'Left'}]
		insert 'locations', id: 2

	'should return true if path exists': mocha ->
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 2
		test.isTrue can

	'should return false if already on this location': mocha ->
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
		test.isFalse can

	"should return false if path doesn't exist": mocha ->
		game.changeLocation.sync null, conn, 1, 2
		can = game.isTherePathForCharacterToLocation.sync null, conn, 1, 1
		test.isFalse can


exports.game._createBattleBetween =
	'should create battle with correct location, turn and sides': mocha ->
		locid = 123
		firstSide = [
			{id: 1, initiative:  5}
			{id: 2, initiative: 15}
			{id: 5, initiative: 30}
		]
		secondSide = [
			{id: 6, initiative: 20}
			{id: 7, initiative: 10}
		]

		game._createBattleBetween conn, locid, firstSide, secondSide

		battle = query.row 'SELECT id, location, turn_number FROM battles'
		participants = query.all 'SELECT character_id AS id, index, side FROM battle_participants WHERE battle = $1', [battle.id]

		test.strictEqual battle.location, locid
		test.strictEqual battle.turn_number, 0
		test.deepEqual participants, [
			{id: 5, index: 0, side: 0}
			{id: 6, index: 1, side: 1}
			{id: 2, index: 2, side: 0}
			{id: 7, index: 3, side: 1}
			{id: 1, index: 4, side: 0}
		]
