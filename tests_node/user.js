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
	conn.query('DROP TABLE IF EXISTS uniusers, locations', [], done);
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

exports.idExists = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers (id INT)', [], callback); },
			function(callback){ conn.query('INSERT INTO uniusers VALUES ( ? )', [ 114 ], callback); },
			function(callback){ users.idExists(conn, 114, callback); },
			function(callback){ users.idExists(conn, 9000, callback); },
			function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[2], true, 'should return true when user exists');
			test.strictEqual(result[3], false, 'should return false when user does not exist');
			test.done();
		}
	);
};

exports.sessionExists = {
	'testNoErrors': function (test) {
		async.series([
				function(callback){ conn.query(
					'CREATE TABLE IF NOT EXISTS uniusers (sessid TINYTEXT)', [], callback); },
				function(callback){ conn.query('INSERT INTO uniusers VALUES ( ? )', [ "someid" ], callback); },
				function(callback){ users.sessionExists(conn, "someid", callback); },
				function(callback){ users.sessionExists(conn, "wrongid", callback); },
				function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
			],
			function(error, result){
				test.ifError(error);
				test.strictEqual(result[2], true, 'should return true when sessid exists');
				test.strictEqual(result[3], false, 'should return false when sessid does not exist');
				test.done();
			}
		);
	},
	'testErrors': function (test) {
		users.sessionExists(conn, "someid", function(error, result) {
			test.ok(error, "should return error without table");
			test.done();
		});
	},
};

exports.sessionInfoRefreshing = {
	'testNoErrors': function (test) {
		async.series([
				function(callback){ conn.query('CREATE TABLE uniusers '+
					'(user TINYTEXT, permissions INT, sessid TINYTEXT, sessexpire DATETIME)', [], callback); },
				function(callback){ conn.query("INSERT INTO uniusers VALUES "+
					"('user0', ?, 'someid', NOW() - INTERVAL 3600 SECOND )",
					[config.PERMISSIONS_ADMIN], callback); },
				function(callback){ users.sessionInfoRefreshing(conn, 'someid', 7200, callback); },
				function(callback){ users.sessionInfoRefreshing(conn, 'someid', 7200, callback); },
				function(callback){ conn.query("UPDATE uniusers "+
					"SET sessexpire = NOW() + INTERVAL 3600 SECOND", [], callback); },
				function(callback){ conn.query("SELECT sessexpire FROM uniusers", [], callback); },//5
				function(callback){ users.sessionInfoRefreshing(conn, 'someid', 7200, callback); },
				function(callback){ conn.query("SELECT sessexpire FROM uniusers", [], callback); },
				function(callback){ users.sessionInfoRefreshing(conn, undefined, 7200, callback); },
				function(callback){ conn.query("INSERT INTO uniusers VALUES "+
					"('user1', ?, 'otherid', NOW() + INTERVAL 3600 SECOND )",
					[config.PERMISSIONS_USER], callback); },
				function(callback){ users.sessionInfoRefreshing(conn, "otherid", 7200, callback); },//10
				function(callback){ conn.query('DROP TABLE uniusers', [], callback); },
			],
			function(error, result){
				test.ifError(error);
				test.deepEqual(result[2], {
						sessionIsActive: false
					}, 'session should not be active if expired');
				test.deepEqual(result[3], {
						sessionIsActive: false
					}, 'sesson expire time should not be updated if expired');
				test.deepEqual(result[6], {
						sessionIsActive: true,
						username: 'user0',
						admin: true
					}, 'session should be active if not expired and user data should be returned');
				test.deepEqual(result[8], {
						sessionIsActive: false
					}, 'should not fail on empty sessid');
				var timeBefore = new Date(result[5].rows[0].sessexpire);
				var timeAfter = new Date(result[7].rows[0].sessexpire);
				test.deepEqual(result[10], {
						sessionIsActive: true,
						username: 'user1',
						admin: false
					}, 'if user is NOT admin, he is NOT admin');
				test.ok(timeBefore < timeAfter, "session expire time should have been updated");
				test.done();
			}
		);
	},
	'testErrors': function(test) {
		users.sessionInfoRefreshing(conn, "someid", 0, function(error, result) {
			test.ok(error, "should return error without table");
			test.done();
		});
	},
};

exports.generateSessId = {
	'testNoErrors': function (test) {
		var _createSalt = users.createSalt;
		var i = 0;
		users.createSalt = function(len) {
			return "someid" + (++i);
		};
		async.series([
				function (callback) {
					conn.query('CREATE TABLE IF NOT EXISTS uniusers (sessid TINYTEXT)', [], callback); },
				function (callback) { conn.query('INSERT INTO uniusers VALUES ( ? )', [ "someid1" ], callback); },
				function (callback) { conn.query('INSERT INTO uniusers VALUES ( ? )', [ "someid2" ], callback); },
				function (callback) { users.generateSessId(conn, 16, callback); },
				function (callback) { conn.query('DROP TABLE uniusers', [], callback); },
			],
			function (error, result) {
				users.createSalt = _createSalt;
				test.ifError(error);
				test.strictEqual(result[3], 'someid3', 'sessid should be unique');
				test.done();
			}
		);
	},
	'testErrors': function(test) {
		users.generateSessId(conn, 16, function(error, result) {
			test.ok(error, "should return error without table");
			test.done();
		});
	},
};

exports.idBySession = {
	'testNoErrors': function (test) {
		async.series([
				function (callback) {
					conn.query('CREATE TABLE IF NOT EXISTS uniusers (id INT, sessid TINYTEXT)', [], callback); },
				function (callback) { conn.query('INSERT INTO uniusers VALUES ( 3, "someid" )', [], callback); },
				function (callback) { users.idBySession(conn, "someid", callback); },
			],
			function (error, result) {
				test.ifError(error);
				test.strictEqual(result[2], 3, 'should return correct user id');
				test.done();
			}
		);
	},
	'testWrongSessid': function (test) {
		async.series([
				function (callback) {
					conn.query('CREATE TABLE IF NOT EXISTS uniusers (id INT, sessid TINYTEXT)', [], callback); },
				function (callback) { users.idBySession(conn, "someid", callback); },
				function (callback) { conn.query('DROP TABLE uniusers', [], callback); },
			],
			function (error, result) {
				test.ok(error, "should return error on wrong sessid");
				test.done();
			}
		);
	},
	'testQueryError': function(test) {
		users.idBySession(conn, "someid", function(error, result) {
			test.ok(error, "should return error without table");
			test.done();
		});
	},
};

exports.closeSession = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE uniusers '+
				'(sessid TINYTEXT, sessexpire DATETIME)', [], callback); },//0
			function(callback){ conn.query("INSERT INTO uniusers VALUES "+
				"('someid', NOW() + INTERVAL 3600 SECOND )", [], callback); },
			function(callback){ users.closeSession(conn, 'someid', callback); },
			function(callback){ conn.query('SELECT sessexpire > NOW() AS active FROM uniusers', callback); },
			function(callback){ users.closeSession(conn, undefined, callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3].rows[0].active, 0, 'session should have expired');
			test.strictEqual(result[4], 'Not closing: empty sessid', 'false sessid should have been detected');
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

exports.registerUser = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers ('+
				'user TINYTEXT, salt TINYTEXT, hash TINYTEXT, sessid TINYTEXT, reg_time DATETIME,'+
				'sessexpire DATETIME, location INT DEFAULT 1, permissions INT DEFAULT 0)', [], callback); },
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS locations'+
				'(id INT, `default` TINYINT(1))', [], callback);},
			function(callback){ conn.query("INSERT INTO locations VALUES (2, 1)", [], callback); },
			function(callback){ users.registerUser(conn, "TheUser", "password", 1, callback); },
			function(callback){ conn.query('SELECT * FROM uniusers', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4].rowCount, 1, 'one registration - one user');
			var user = result[4].rows[0];
			test.ok(user.salt.length > 0, 'salt should be set');
			test.ok(user.hash.length > 0, 'hash should be set');
			test.ok(user.sessid.length > 0, 'sessid should be set');
			test.ok(user.reg_time <= new Date(), 'should not put registration time in future');
			test.ok(user.sessexpire > new Date(), 'session should not have been expired');
			test.strictEqual(user.location, 2, 'user should have been spawned on default location');
			test.strictEqual(user.permissions, 1, 'user should have specified permissions');
			test.done();
		}
	);
};

exports.accessGranted = {
	'testNoErrors': function (test) {
		async.series([
				function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers ('+
					'user TINYTEXT, salt TINYTEXT, hash TINYTEXT, sessid TINYTEXT, reg_time DATETIME,'+
					'sessexpire DATETIME, location INT DEFAULT 1, permissions INT DEFAULT 0)', [], callback); },
				function(callback){ conn.query('CREATE TABLE IF NOT EXISTS locations'+
					'(id INT, `default` TINYINT(1))', [], callback);},
				function(callback){ conn.query("INSERT INTO locations VALUES (2, 1)", [], callback); },
				function(callback){ users.registerUser(conn, "TheUser", "password", 1, callback); },
				function(callback){ users.accessGranted(conn, "TheUser", "password", callback); },
				function(callback){ users.accessGranted(conn, "WrongUser", "password", callback); },
				function(callback){ users.accessGranted(conn, "TheUser", "wrongpass", callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[4], true, "access should be granted for valid data");
				test.strictEqual(result[5], false, "access should NOT be granted if user does not exists");
				test.strictEqual(result[6], false, "access should NOT be granted if password is wrong");
				test.done();
			}
		);
	},
	'testErrors': function (test) {
		users.accessGranted(conn, "TheUser", "password", function(error, result) {
			test.ok(error);
			test.done();
		});
	},
};

exports.setSession = {
	'testNoErrors': function (test) {
		async.series([
				function(callback){ conn.query('CREATE TABLE IF NOT EXISTS uniusers ('+
					'id INT AUTO_INCREMENT, PRIMARY KEY (id), user TINYTEXT, '+
					'salt TINYTEXT, hash TINYTEXT, sessid TINYTEXT, reg_time DATETIME, '+
					'sessexpire DATETIME, location INT DEFAULT 1, permissions INT DEFAULT 0)', [], callback); },//0
				function(callback){ conn.query('CREATE TABLE IF NOT EXISTS locations'+
					'(id INT, `default` TINYINT(1))', [], callback);},
				function(callback){ conn.query("INSERT INTO locations VALUES (2, 1)", [], callback); },
				function(callback){ users.registerUser(conn, "TheUser", "password", 1, callback); },
				function(callback){ conn.query('SELECT sessid FROM uniusers', [], callback);},
				function(callback){ users.setSession(conn, 'TheUser', callback); },//5
				function(callback){ conn.query('SELECT sessid, sessexpire FROM uniusers', [], callback);},
			],
			function(error, result) {
				test.ifError(error);
				test.ok(result[4].rows[0].sessid !== result[6].rows[0].sessid, "Sessid should have changed");
				test.ok(result[6].rows[0].sessexpire > new Date(), 'session should not have been expired');
				test.done();
			}
		);
	},
	'testErrors': function (test) {
		users.setSession(conn, 1, function(error, result) {
			test.ok(error);
			test.done();
		});
	},
};

