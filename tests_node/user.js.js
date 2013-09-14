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

var jsc = require('jscoverage');
jsc.enableCoverage(true);

var users = jsc.require(module, '../utils/user.js');

var async = require('async');

var anyDB = require('any-db');
var dbURL = process.env.MYSQL_DATABASE_URL || 'mysql://anonymous:nopassword@localhost/uonline';
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(dbURL);
	done();
};

exports.tearDown = function (done) {
	conn.end();
	done();
};

exports.userExists = function (test) {
	users.userExists(conn, 'm1kc', function(error, result){
		test.ok(!!error, 'should fail on nonexistent table');
	}, 'test_nonexistent_table');

	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS test_users (user TINYTEXT NOT NULL)', [], callback); },
			function(callback){ conn.query('INSERT INTO test_users VALUES ( ? )', ['m1kc'], callback); },
			function(callback){ users.userExists(conn, 'm1kc', callback, 'test_users'); },
			function(callback){ conn.query("TRUNCATE test_users", [], callback); },
			function(callback){ users.userExists(conn, 'm1kc', callback, 'test_users'); },
			function(callback){ conn.query('DROP TABLE test_users', [], callback); },
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[2], true, 'user should exist after inserted');
			test.strictEqual(result[4], false, 'user should not exist after deleted');
			test.done();
		}
	);
};
