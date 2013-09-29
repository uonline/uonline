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

exports.setUp = function (done) {
	conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
	//conn.query("DROP TABLE IF EXISTS locations;", done);
	done();
};

exports.tearDown = function (done) {
	conn.end();
	done();
};


exports.getDefaultLocation = function (test) {
	async.series([
			function(callback){ conn.query('DROP TABLE IF EXISTS locations', callback); },
			function(callback){ conn.query('CREATE TABLE locations '+
				'(`id` INT, PRIMARY KEY (`id`), `default` TINYINT(1) DEFAULT 0 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 1, 0 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 2, 1 )', callback); },
			function(callback){ conn.query('INSERT INTO locations VALUES ( 3, 0 )', callback); },
			function(callback){ game.getDefaultLocation(conn, callback); },
			function(callback){ conn.query('DROP TABLE locations', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[5], 2, 'should return id of default location');
			test.done();
		}
	);
};

exports.getUserLocationId = function (test) {
	async.series([
			function(callback){ conn.query('DROP TABLE IF EXISTS uniusers', callback); },
			function(callback){ conn.query('CREATE TABLE uniusers '+
				'(`id` INT, PRIMARY KEY (`id`), `location` INT DEFAULT 1, `sessid` TINYTEXT )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers              VALUES ( 1, 3, "qweasd" )', callback); },
			function(callback){ conn.query('INSERT INTO uniusers (id, sessid) VALUES ( 2,    "asdzxc" )', callback); },
			function(callback){ game.getUserLocationId(conn, "qweasd", callback); },
			function(callback){ game.getUserLocationId(conn, "asdzxc", callback); },
			function(callback){ conn.query('DROP TABLE uniusers', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4], 3, 'user location should be 3');
			test.strictEqual(result[5], 1, 'user location should be 1 (by default)');
			test.done();
		}
	);
};

