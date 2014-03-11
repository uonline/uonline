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

var tables = require('../lib/tables.js');

var mg = require('../lib-cov/migration');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

var migrationData = [
	[
		['test_table', 'create', 'id INT'],
		['other_table', 'create', 'id INT'],
	],
	[
		['test_table', 'addCol', 'col0 BOX'],
		['test_table', 'addCol', 'col1 MACADDR'],
	],
	[
		['test_table', 'addCol', 'col3 INT'],
		['test_table', 'changeCol', 'col3', 'BIGINT'],
		['test_table', 'renameCol', 'col3', 'col2'],
		['other_table', 'addCol', 'col0 LSEG'],
	],
	[
		['test_table', 'addCol', 'col3 MONEY'],
		['test_table', 'dropCol', 'col3'],
	],
];

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.DATABASE_URL_TEST);
	conn.query("DROP TABLE IF EXISTS test_table, other_table, revision", done);
	mg.setMigrationsData(migrationData);
};

exports.tearDown = function (done) {
	conn.end();
	done();
};

exports.getCurrentRevision = {
	'usual': function (test) {
		async.series([
				function (callback) { mg.getCurrentRevision(conn, callback); },
				function (callback) { conn.query('CREATE TABLE revision (revision INT)', [], callback); },
				function (callback) { conn.query('INSERT INTO revision VALUES (945)', [], callback); },
				function (callback) { mg.getCurrentRevision(conn, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[0], -1, 'should return default value if revision table is not created');
				test.strictEqual(result[3], 945, 'should return current revision number');
				test.done();
			}
		);
	},
	'exceptions': function (test) {
		async.parallel([
				function (callback) { mg.getCurrentRevision('nonsense', callback); },
			],
			function(error, result) {
				test.ok(!!error, 'should fail on exceptions');
				test.done();
			}
		);
	},
	/* 'connection errors': function (test) {
		var fakeConn = anyDB.createConnection('postgres://nobody:nothing@127.0.0.1:11111/nowhere');
		async.parallel([
				function (callback) { mg.getCurrentRevision(fakeConn, callback); },
			],
			function(error, result) {
				test.ok(!!error, 'should fail on connection errors');
				test.done();
			}
		);
	}, */
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
				function(callback){ mg.migrateOne(conn, 0, callback); },
				function(callback){ conn.query(
					"SELECT column_name FROM information_schema.columns "+
					"WHERE table_name = 'test_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ conn.query(
					"SELECT column_name FROM information_schema.columns "+
					"WHERE table_name = 'other_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ mg.migrateOne(conn, 1, callback); },
				function(callback){ mg.migrateOne(conn, 1, callback); },
				function(callback){ conn.query(
					"SELECT column_name FROM information_schema.columns "+
					"WHERE table_name = 'test_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ conn.query(
					"SELECT column_name FROM information_schema.columns "+
					"WHERE table_name = 'other_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ mg.getCurrentRevision(conn, callback); },
			],
			function(error, result) {
				test.ifError(error, 'should not fail if destination revision is current');

				test.ok(
					result[1].rows.length === 1 &&
					result[1].rows[0].column_name === 'id' &&
					result[2].rows.length === 1 &&
					result[2].rows[0].column_name === 'id', 'should correctly perform first migration');

				test.ok(
					result[5].rows.length === 3 &&
					result[5].rows[0].column_name === 'col0' &&
					result[5].rows[1].column_name === 'col1' &&
					result[5].rows[2].column_name === 'id' &&
					result[6].rows.length === 1 &&
					result[6].rows[0].column_name === 'id', 'should correctly add second migration');

				test.strictEqual(result[7], 1, 'should update revision');

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

exports.migrate = {
	'usual test': function(test) {
		async.series([
				function(callback){ mg.migrate(conn, 1, callback); },
				function(callback){ conn.query(
					"SELECT column_name, data_type FROM information_schema.columns "+
					"WHERE table_name = 'test_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ conn.query(
					"SELECT column_name, data_type FROM information_schema.columns "+
					"WHERE table_name = 'other_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ mg.getCurrentRevision(conn, callback); },
				function(callback){ mg.migrate(conn, callback); },
				function(callback){ conn.query(
					"SELECT column_name, data_type FROM information_schema.columns "+
					"WHERE table_name = 'test_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ conn.query(
					"SELECT column_name, data_type FROM information_schema.columns "+
					"WHERE table_name = 'other_table' ORDER BY column_name",
					[], callback);
				},
				function(callback){ mg.getCurrentRevision(conn, callback); },
			],
			function(error, result) {
				test.ifError(error);

				var rows = result[1].rows;
				var orows = result[2].rows;
				test.ok(
					rows.length === 3 &&
					rows[0].column_name === 'col0' &&
					rows[1].column_name === 'col1' &&
					rows[2].column_name === 'id' &&
					rows[0].data_type === 'box' &&
					rows[1].data_type === 'macaddr' &&
					rows[2].data_type === 'integer' &&
					orows.length === 1 &&
					orows[0].column_name === 'id' &&
					orows[0].data_type === 'integer', 'should correctly perform part of migrations');
				test.strictEqual(result[3], 1, 'should set correct revision');

				rows = result[5].rows;
				orows = result[6].rows;
				test.ok(
					rows.length === 4 &&
					rows[0].column_name === 'col0' &&
					rows[1].column_name === 'col1' &&
					rows[2].column_name === 'col2' &&
					rows[3].column_name === 'id' &&
					rows[0].data_type === 'box' &&
					rows[1].data_type === 'macaddr' &&
					rows[2].data_type === 'bigint' &&
					rows[3].data_type === 'integer' &&
					orows.length === 2 &&
					orows[0].column_name === 'col0' &&
					orows[1].column_name === 'id' &&
					orows[0].data_type === 'lseg' &&
					orows[1].data_type === 'integer', 'should correctly perform all remaining migrations');
				test.strictEqual(result[7], 3, 'should set correct revision');

				test.done();
			}
		);
	},
	'for one table': function(test) {
		async.series([
				function(callback) {mg.getCurrentRevision(conn, callback);},
				function(callback) {mg.migrate(conn, 0, 'test_table', callback);},
				function(callback) {mg.getCurrentRevision(conn, callback);},
				function(callback){ conn.query(
					"SELECT column_name, data_type FROM information_schema.columns "+
					"WHERE table_name = 'test_table' ORDER BY column_name",
					[], callback);
				},
				function(callback) {tables.tableExists(conn, "other_table", callback);},
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[0], result[2], "should not change version for one table");
				test.ok(
					result[3].rows.length === 1 &&
					result[3].rows[0].column_name === 'id',
					'should correctly perform migration for specified table');
				test.ok(!result[4], 'migration for other tables should not have been performed');
				test.done();
			}
		);
	}
};
