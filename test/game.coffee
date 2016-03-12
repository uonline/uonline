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


insert = (dbName, fields) ->
	values = (v for _,v of fields)
	query "INSERT INTO #{dbName} (#{k for k of fields}) "+
	      "VALUES (#{values.map (v,i) -> '$'+(i+1)+(if v? and typeof v is 'object' then '::json' else '')})",
		values.map((v) -> if v? and typeof v is 'object' then JSON.stringify(v) else v)


exports.beforeEach = (done) ->
	sync ->
		unless _conn?
			_conn = anyDB.createConnection(config.DATABASE_URL_TEST)
			mg.migrate.sync mg, _conn
		conn = transaction(_conn)
		query = queryUtils.getFor conn
		done()

exports.afterEach = (done) ->
	sync ->
		conn.rollback.sync(conn)
		done()


exports.getInitialLocation =
	beforeEach: (done) -> sync -> done()  # it fixes all 'getInitialLocation'
	'good test': ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3

		loc = game.getInitialLocation.sync null, conn
		assert.strictEqual loc.id, 2, 'should return id of initial location'
		assert.instanceOf loc.ways, Array, 'should return parsed ways from location'

	'bad test': ->
		insert 'locations', id: 1
		insert 'locations', id: 2
		insert 'locations', id: 3

		assert.throws(
			-> game.getInitialLocation.sync null, conn
			Error, null,
			'should return error if initial location is not defined'
		)

	'ambiguous test': ->
		insert 'locations', id: 1
		insert 'locations', id: 2, initial: 1
		insert 'locations', id: 3, initial: 1
		insert 'locations', id: 4

		assert.throws(
			-> game.getInitialLocation.sync null, conn
			Error, null,
			'should return error if there is more than one initial location'
		)
