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

var tables = require('../utils/tables.js');

var jsc = require('jscoverage');
jsc.enableCoverage(true);

var mg = jsc.require(module, '../utils/migration.js');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

var migrationData = [
	[
		['test_table', 'create', 'id INT'],
	],
	[
		['test_table', 'addCol', 'col0 INT(1)'],
		['test_table', 'addCol', 'col1 INT(2)'],
	],
	[
		['test_table', 'addCol', 'col3 INT'],
		['test_table', 'changeCol', 'col3', 'INT(3)'],
		['test_table', 'renameCol', 'col3', 'col2'],
	],
	[
		['test_table', 'addCol', 'col3 INT'],
		['test_table', 'dropCol', 'col3'],
	],
];

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
	conn.query("DROP TABLE IF EXISTS test_table, revision", done);
	mg.setMigrationsData(migrationData);
};

exports.getCurrentRevision = function(test) {
	async.series([
			function(callback) {mg.getCurrentRevision(conn, callback);},
			function(callback) {conn.query("CREATE TABLE revision (revision INT)", [], callback);},
			function(callback) {conn.query("INSERT INTO revision VALUES (1)", [], callback);},
			function(callback) {mg.getCurrentRevision(conn, callback);},
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[0], -1, "should return default value if revision table is not created");
			test.strictEqual(result[3], 1, "should return correct value if revision table is created");
			test.done();
		}
	);
};

exports.setRevision = function(test) {
	async.series([
			function(callback) {mg.setRevision(conn, 1, callback);},
			function(callback) {tables.tableExists(conn, 'revision', callback);},
			function(callback) {mg.getCurrentRevision(conn, callback);},
			function(callback) {mg.setRevision(conn, 2, callback);},
			function(callback) {mg.getCurrentRevision(conn, callback);},
		],
		function(error, result) {
			test.ifError(error);
			test.ok(result[1], 'table should have been created');
			test.strictEqual(result[2], 1, 'revision should have been set');
			test.strictEqual(result[4], 2, 'revision should have been updated');
			test.done();
		}
	);
};

exports.migrateOne = {
	'testNoErrors': function(test) {
		async.series([
				function(callback) {mg.migrateOne(conn, 0, callback);},
				function(callback) {conn.query("DESCRIBE test_table", callback);},
				function(callback) {mg.migrateOne(conn, 1, callback);},
				function(callback) {mg.migrateOne(conn, 1, callback);},
				function(callback) {conn.query("DESCRIBE test_table", callback);},
				function(callback) {mg.getCurrentRevision(conn, callback);},
			],
			function(error, result) {
				test.ifError(error, 'should not fail if destination revision is current');
				
				test.ok(
					result[1].rows.length === 1 &&
					result[1].rows[0].Field === 'id', 'should correctly perform first migration');
				
				test.ok(
					result[4].rows.length === 3 &&
					result[4].rows[0].Field === 'id' &&
					result[4].rows[1].Field === 'col0' &&
					result[4].rows[2].Field === 'col1', 'should correctly add second migration');
				
				test.strictEqual(result[5], 1, 'should update revision');
				
				test.done();
			}
		);
	},
	'testTooNew': function(test) {
		async.series([
				function(callback) {mg.migrateOne(conn, 1, callback);},
			],
			function(error, result) {
				test.ok(error, 'should fail if destination revision is too new');
				test.done();
			}
		);
	},
	'testTooOld': function(test) {
		async.series([
				function(callback) {mg.migrateOne(conn, 0, callback);},
				function(callback) {mg.migrateOne(conn, 1, callback);},
				function(callback) {mg.migrateOne(conn, 0, callback);},
			],
			function(error, result) {
				test.ok(error, 'should fail if destination revision is too old');
				test.done();
			}
		);
	},
	'testErrors': function(test) {
		async.series([
				function(callback) {conn.query("DROP TABLE IF EXISTS test_table", callback);},
				function(callback) {mg.setRevision(conn, 0, callback);},
				function(callback) {mg.migrateOne(conn, 1, callback);},
			],
			function(error, result) {
				test.ok(error, 'should return error if has failed to migrate');
				test.done();
			}
		);
	},
};

exports.migrate = function(test) {
	async.series([
			function(callback) {mg.migrate(conn, 1, callback);},
			function(callback) {conn.query("DESCRIBE test_table", callback);},
			function(callback) {mg.getCurrentRevision(conn, callback);},
			function(callback) {mg.migrate(conn, callback);},
			function(callback) {conn.query("DESCRIBE test_table", callback);},
			function(callback) {mg.getCurrentRevision(conn, callback);},
		],
		function(error, result) {
			test.ifError(error);
			
			var rows = result[1].rows;
			test.ok(
				rows.length === 3 &&
				rows[0].Field === 'id' &&
				rows[1].Field === 'col0' &&
				rows[2].Field === 'col1' &&
				rows[0].Type === 'int(11)' &&
				rows[1].Type === 'int(1)' &&
				rows[2].Type === 'int(2)', 'should correctly perform part of migrations');
			test.strictEqual(result[2], 1, 'should set correct revision');
			
			rows = result[4].rows;
			test.ok(
				rows.length === 4 &&
				rows[0].Field === 'id' &&
				rows[1].Field === 'col0' &&
				rows[2].Field === 'col1' &&
				rows[3].Field === 'col2' &&
				rows[0].Type === 'int(11)' &&
				rows[1].Type === 'int(1)' &&
				rows[2].Type === 'int(2)' &&
				rows[3].Type === 'int(3)', 'should correctly perform all remaining migrations');
			test.strictEqual(result[5], 3, 'should set correct revision');
			
			test.done();
		}
	);
};

exports.tearDown = function (done) {
	conn.query("DROP TABLE IF EXISTS test_table", function() {
		conn.end();
		done();
	});
};

