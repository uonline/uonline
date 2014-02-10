/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


"use strict";

var config = require('../config.js');

var jsc = require('jscoverage');
jsc.enableCoverage(true);

var tables = jsc.require(module, '../lib/tables.js');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
	conn.query("DROP TABLE IF EXISTS test_table", done);
	//done();
};

exports.tearDown = function (done) {
	conn.query("DROP TABLE IF EXISTS test_table", function() {
		conn.end();
		done();
	});
};

exports.tableExists = function (test) {
	test.expect(6);
	conn.query('CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)', [], function(err, res){
		test.ifError(err);
		tables.tableExists(conn, 'test_table', function(err, res){
			test.ifError(err);
			test.strictEqual(res, true, 'table should exist after created');
			conn.query('DROP TABLE test_table', [], function(err, res){
				test.ifError(err);
				tables.tableExists(conn, 'test_table', function(err, res){
					test.ifError(err);
					test.strictEqual(res, false, 'table should not exist after dropped');
					test.done();
				});
			});
		});
	});
};

exports.tableExistsAsync = function (test) {
	async.series([
			function(callback){ conn.query(
				'CREATE TABLE IF NOT EXISTS test_table (id INT NOT NULL)', [], callback); },
			function(callback){ tables.tableExists(conn, 'test_table', callback); },
			function(callback){ conn.query('DROP TABLE test_table', [], callback); },
			function(callback){ tables.tableExists(conn, 'test_table', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[1], true, 'table should exist after created');
			test.strictEqual(result[3], false, 'table should not exist after dropped');
			test.done();
		}
	);
};

exports.create = function (test) {
	async.series([
			function(callback){ tables.create(conn, 'test_table', 'id INT', callback); },
			function(callback){ tables.tableExists(conn, 'test_table', callback); },
			function(callback){ conn.query('DESCRIBE test_table', [], callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[1], true, 'table should exist after created');
			test.strictEqual(result[2].rows[0].Field, 'id', 'first column should exist');
			test.done();
		}
	);
};

exports.addCol = function (test) {
	async.series([
			function(callback){ tables.create(conn, 'test_table', 'id INT', callback); },
			function(callback){ tables.addCol(conn, 'test_table', 'col INT(10)', callback); },
			function(callback){ conn.query('DESCRIBE test_table', [], callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[2].rows[1].Field, 'col', 'column shold exist after created');
			test.strictEqual(result[2].rows[1].Type, 'int(10)', 'column type should be correct');
			test.done();
		}
	);
};

exports.renameCol = {
	'testNoErrors': function (test) {
		async.series([
				function(callback){ tables.create(conn, 'test_table', 'id INT(9)', callback); },
				function(callback){ tables.renameCol(conn, 'test_table', 'id', 'col', callback); },
				function(callback){ conn.query('DESCRIBE test_table', [], callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[2].rows[0].Field, 'col', 'column shold have been renamed');
				test.strictEqual(result[2].rows[0].Type, 'int(9)', 'column type should be same');
				test.done();
			}
		);
	},
	'testNoTable': function (test) {
		tables.renameCol(conn, 'test_table', 'id', 'col', function(error, result) {
			test.ok(error, 'No table - no renaming');
			test.done();
		});
	},
	'testNoColumn': function (test) {
		async.series([
				function(callback){ tables.create(conn, 'test_table', 'id INT(9)', callback); },
				function(callback){ tables.renameCol(conn, 'test_table', 'noSuchCol', 'col', callback); },
			],
			function(error, result) {
				test.ok(error, 'No column - no renaming');
				test.done();
			}
		);
		
	}
};

exports.changeCol = function (test) {
	async.series([
			function(callback){ tables.create(conn, 'test_table', 'id INT', callback); },
			function(callback){ tables.changeCol(conn, 'test_table', 'id', 'int(1)', callback); },
			function(callback){ conn.query('DESCRIBE test_table', [], callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[2].rows[0].Type, 'int(1)', 'column type should have changed');
			test.done();
		}
	);
};

exports.dropCol = function (test) {
	async.series([
			function(callback){ tables.create(conn, 'test_table', 'id INT', callback); },
			function(callback){ tables.addCol(conn, 'test_table', 'col INT(10)', callback); },
			function(callback){ tables.dropCol(conn, 'test_table', 'col', callback); },
			function(callback){ conn.query('DESCRIBE test_table', [], callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3].rows.length, 1, 'column shold have been removed');
			test.strictEqual(result[3].rows[0].Field, 'id', 'correct column shold have been removed');
			test.done();
		}
	);
};

