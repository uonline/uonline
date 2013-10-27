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

jsc = require 'jscoverage'
jsc.enableCoverage true

tables = jsc.require module, '../utils/tables.js'

async = require 'async'

anyDB = require 'any-db'
conn = null


exports.setUp = (done) ->
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST)
	done()


exports.tearDown = (done) ->
	conn.end()
	done()


exports.tableExists = (test) ->
	test.expect 6
	conn.query "CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)", [], (error, result) ->
		test.ifError error
		tables.tableExists conn, 'test_table', (error, result) ->
			test.ifError error
			test.strictEqual result, true, 'table should exist after created'
			conn.query "DROP TABLE test_table", [], (error, result) ->
				test.ifError error
				tables.tableExists conn, 'test_table', (error, result) ->
					test.ifError error
					test.strictEqual result, false, 'table should not exist after dropped'
					test.done()


exports.tableExistsAsync = (test) ->
	async.series [
		(callback) ->
			conn.query "CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)", [], callback
		(callback) ->
			tables.tableExists conn, 'test_table', callback
		(callback) ->
			conn.query "DROP TABLE test_table", [], callback
		(callback) ->
			tables.tableExists conn, 'test_table', callback
	],
	(error, result) ->
		test.ifError error
		test.strictEqual result[1], true, 'table should exist after created'
		test.strictEqual result[3], false, 'table should not exist after dropped'
		test.done()
