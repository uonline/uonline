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
tables = require '../lib-cov/tables'
async = require 'async'
sync = require 'sync'
anyDB = require 'any-db'
conn = null


exports.setUp = (done) -> sync ->
	conn = anyDB.createConnection(config.DATABASE_URL_TEST)
	conn.query.sync conn, 'DROP TABLE IF EXISTS test_table, akira'
	done()


exports.tearDown = (done) -> sync ->
	conn.query.sync conn, 'DROP TABLE IF EXISTS test_table, akira'
	conn.end()
	done()


exports.tableExists = (test) -> sync ->
	try
		conn.query.sync conn, 'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)', []
		test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), true,
			'should return true if table exists'
		conn.query.sync conn, 'DROP TABLE test_table', []
		test.strictEqual tables.tableExists.sync(null, conn, 'test_table'), false,
			'should return false if table does not exist'
		test.done()
	catch ex
		test.ifError ex
		test.done()


exports.create = (test) -> sync ->
	try
		tables.create.sync null, conn, 'akira', 'id INT'
		test.strictEqual tables.tableExists.sync(null, conn, 'akira'), true, 'should create table'
		dsc = conn.query.sync conn,
			"SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'akira'", []
		test.strictEqual dsc.rows[0].result, 'id', 'and its columns'
		test.done()
	catch ex
		test.ifError ex
		test.done()


exports.addCol = (test) -> sync ->
	try
		tables.create.sync null, conn, 'test_table', 'id INT'
		tables.addCol.sync null, conn, 'test_table', 'zoich INT'
		dsc = conn.query.sync conn,
			"SELECT column_name AS result FROM information_schema.columns WHERE table_name = 'test_table'", []
		test.strictEqual dsc.rows.length, 2, 'should create a new column'
		test.done()
	catch ex
		test.ifError ex
		test.done()


exports.renameCol =
	testNoErrors: (test) ->
		async.series [
			(callback) ->
				tables.create conn, "test_table", "id INTEGER", callback
			(callback) ->
				tables.renameCol conn, "test_table", "id", "col", callback
			(callback) ->
				conn.query "SELECT column_name, data_type FROM information_schema.columns " +
					"WHERE table_name = 'test_table'", [], callback
		], (error, result) ->
			test.ifError error
			test.strictEqual result[2].rows[0].column_name, "col", "should rename column"
			test.strictEqual result[2].rows[0].data_type, "integer", "should not alter its type"
			test.done()

	testNoTable: (test) ->
		tables.renameCol conn, "test_table", "id", "col", (error, result) ->
			test.ok error, "No table - no renaming"
			test.done()

	testNoColumn: (test) ->
		async.series [
			(callback) ->
				tables.create conn, "test_table", "id INT(9)", callback
			(callback) ->
				tables.renameCol conn, "test_table", "noSuchCol", "col", callback
		], (error, result) ->
			test.ok error, "No column - no renaming"
			test.done()


exports.changeCol = (test) ->
	async.series [
		(callback) ->
			tables.create conn, "test_table", "id SMALLINT", callback
		(callback) ->
			tables.changeCol conn, "test_table", "id", "INTEGER", callback
		(callback) ->
			conn.query "SELECT column_name, data_type FROM information_schema.columns "+
				"WHERE table_name = 'test_table'", [], callback
	], (error, result) ->
		test.ifError error
		test.strictEqual result[2].rows[0].data_type, "integer", "column type should have changed"
		test.done()


exports.dropCol = (test) ->
	async.series [
		(callback) ->
			tables.create conn, "test_table", "id INTEGER", callback
		(callback) ->
			tables.addCol conn, "test_table", "col INTEGER", callback
		(callback) ->
			tables.dropCol conn, "test_table", "col", callback
		(callback) ->
			conn.query "SELECT column_name, data_type FROM information_schema.columns "+
				"WHERE table_name = 'test_table'", [], callback
	], (error, result) ->
		test.ifError error
		test.strictEqual result[3].rows.length, 1, "column shold have been removed"
		test.strictEqual result[3].rows[0].column_name, "id", "correct column shold have been removed"
		test.done()
