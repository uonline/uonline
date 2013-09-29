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

var game = jsc.require(module, '../utils/game.js');

var async = require('async');

var anyDB = require('any-db');
var dbURL = process.env.MYSQL_DATABASE_URL || 'mysql://anonymous:nopassword@localhost/uonline';
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(dbURL);
	//conn.query("DROP TABLE IF EXISTS locations;", done);
	done();
};

exports.tearDown = function (done) {
	conn.end();
	done();
};


exports.defaultLocation = function (test) {
	async.series([
			function(callback){ conn.query('DROP TABLE IF EXISTS test_locations', callback); },
			function(callback){ conn.query('CREATE TABLE test_locations (`id` INT, PRIMARY KEY (`id`), `default` TINYINT(1) DEFAULT 0 )', callback); },
			function(callback){ conn.query('INSERT INTO test_locations VALUES ( 1, 0 )', callback); },
			function(callback){ conn.query('INSERT INTO test_locations VALUES ( 2, 1 )', callback); },
			function(callback){ conn.query('INSERT INTO test_locations VALUES ( 3, 0 )', callback); },
			function(callback){ game.getDefaultLocation(conn, callback, 'test_locations'); },
			function(callback){ conn.query('DROP TABLE test_locations', callback); },
		],
		function(error, result){
			console.log("callback")
			test.ifError(error);
			//test.strictEqual(result[5], 2, '');
			test.done();
		}
	);
};
