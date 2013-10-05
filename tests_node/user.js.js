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

var users = jsc.require(module, '../utils/user.js');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
	done();
};

exports.tearDown = function (done) {
	conn.end();
	done();
};

exports.userExists = function (test) {
	users.userExists(conn, 'm1kc', function(error, result){
		test.ok(!!error, 'should fail on nonexistent table');
	});

	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers (user TINYTEXT)', [], callback); },
			function(callback){ conn.query('INSERT INTO uniusers VALUES ( ? )', ['m1kc'], callback); },
			function(callback){ users.userExists(conn, 'm1kc', callback); },
			function(callback){ conn.query("TRUNCATE uniusers", [], callback); },
			function(callback){ users.userExists(conn, 'm1kc', callback); },
			function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[2], true, 'user should exist after inserted');
			test.strictEqual(result[4], false, 'user should not exist after deleted');
			test.done();
		}
	);
};

exports.sessionActive = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers '+
				'(sessid TINYTEXT, sessexpire DATETIME)', [], callback); },
			function(callback){ conn.query("INSERT INTO uniusers VALUES "+
				"( 'abcd', NOW() - INTERVAL 3600 SECOND )", [], callback); },
			function(callback){ users.sessionActive(conn, 'abcd', callback); },
			function(callback){ conn.query("UPDATE uniusers "+
				"SET sessexpire = NOW() + INTERVAL 3600 SECOND WHERE sessid = 'abcd'", [], callback); },
			function(callback){ users.sessionActive(conn, 'abcd', callback); },
			function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[2], false, 'session should not be active if expired');
			test.strictEqual(result[4], true, 'session should be active if not expired');
			test.done();
		}
	);
};

exports.createSalt = function (test) {
	var result;

	result = users.createSalt(50);
	test.strictEqual(result.length, 50, 'should keep specified length');
	test.ok(( /^[a-zA-Z0-9]+$/ ).test(result), 'should contain printable characters');

	result = users.createSalt(10);
	test.strictEqual(result.length, 10, 'should keep specified length');
	test.ok(( /^[a-zA-Z0-9]+$/ ).test(result), 'should contain printable characters');

	test.done();
};

exports.refreshSession = function(test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers '+
				'(sessid TINYTEXT, sessexpire DATETIME)', [], callback); },
			function(callback){ conn.query("INSERT INTO uniusers VALUES "+
				"( 'abcd', NOW() - INTERVAL 3600 SECOND )", [], callback); },
			function(callback){ users.sessionActive(conn, 'abcd', callback); },
			function(callback){ users.refreshSession(conn, 'abcd', 3600, callback); },
			function(callback){ users.sessionActive(conn, 'abcd', callback); },
			function(callback){ conn.query("UPDATE uniusers "+
				"SET sessexpire = sessexpire - INTERVAL 3601 SECOND ", [], callback); },
			function(callback){ users.sessionActive(conn, 'abcd', callback); },
			function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[2], false, 'session should not be active before refresh');
			test.strictEqual(result[4], true, 'session should be active after refresh');
			test.strictEqual(result[6], false, 'session should not be active after expire');
			test.done();
		}
	);
};

