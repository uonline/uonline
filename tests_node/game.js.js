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

var game = jsc.require(module, '../utils/game.js');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

var usedTables = "locations, uniusers";

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
	conn.query("DROP TABLE IF EXISTS "+usedTables, done);
};

exports.tearDown = function (done) {
	conn.query("DROP TABLE IF EXISTS "+usedTables, done);
	conn.end();
};


exports.getDefaultLocation = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE locations '+
				'(`id` INT, PRIMARY KEY (`id`), `default` TINYINT(1) DEFAULT 0 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 1, 0 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 2, 1 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 3, 0 )', callback); },
			function(callback){ game.getDefaultLocation(conn, callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4], 2, 'should return id of default location');
			test.done();
		}
	);
};

exports.getUserLocationId = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE uniusers '+
				'(`id` INT, PRIMARY KEY (`id`), `location` INT DEFAULT 1, `sessid` TINYTEXT )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers              VALUES ( 1, 3, "qweasd" )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers (id, sessid) VALUES ( 2,    "asdzxc" )', callback); },
			function(callback){ game.getUserLocationId(conn, "qweasd", callback); },
			function(callback){ game.getUserLocationId(conn, "asdzxc", callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3], 3, "should return user's location id");
			test.strictEqual(result[4], 1, "should return user's location id");
			test.done();
		}
	);
};

exports.getUserAreaId = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE uniusers '+
				'(`id` INT, PRIMARY KEY (`id`), `location` INT DEFAULT 1, `sessid` TINYTEXT )', callback); },
			function(callback){ conn.query('CREATE TABLE locations '+
				'(`id` INT, PRIMARY KEY (`id`), `area` INT )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers VALUES ( 1, 3, "qweasd" )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 3, 5 )', callback); },
			function(callback){ game.getUserAreaId(conn, "qweasd", callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4], 5, "should return user's area id");
			test.done();
		}
	);
};

exports.getCurrentLocationTitle = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE uniusers '+
				'(`id` INT, PRIMARY KEY (`id`), `location` INT DEFAULT 1, `sessid` TINYTEXT )', callback); },
			function(callback){ conn.query('CREATE TABLE locations '+
				'(`id` INT, PRIMARY KEY (`id`), `title` TINYTEXT )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers VALUES ( 1, 3, "qweasd" )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 3, "sometitle" )', callback); },
			function(callback){ game.getCurrentLocationTitle(conn, "qweasd", callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4], "sometitle", "should return user's location title");
			test.done();
		}
	);
};


