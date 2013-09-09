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

var tables = require('../utils/tables.js');

var async = require('async');

var anyDB = require('any-db');
var dbURL = process.env.MYSQL_DATABASE_URL || 'mysql://anonymous:nopassword@localhost/uonline';
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(dbURL);
	done();
}

exports.tearDown = function (done) {
	conn.end();
	done();
}

exports.tableExists = function (test) {
	test.expect(6);
	conn.query('CREATE TABLE testtable (id INT NOT NULL)', [], function(err, res){
		test.ifError(err);
		tables.tableExists(conn, 'testtable', function(err, res){
			test.ifError(err);
			test.strictEqual(res, true, 'table should exist after created');
			conn.query('DROP TABLE testtable', [], function(err, res){
				test.ifError(err);
				tables.tableExists(conn, 'testtable', function(err, res){
					test.ifError(err);
					test.strictEqual(res, false, 'table should not exist after dropped');
					test.done();
				});
			});
		});
	});
}

exports.tableExistsAsync = function (test) {
	async.series([
			function(callback){ conn.query('CREATE TABLE IF NOT EXISTS testtable (id INT NOT NULL)', [], callback); },
			async.apply(tables.tableExists, conn, 'testtable'),
			function(callback){ conn.query('DROP TABLE testtable', [], callback); },
			async.apply(tables.tableExists, conn, 'testtable'),
		],
		function(error, result){
			test.ifError(error);
			test.strictEqual(result[1], true, 'table should exist after created');
			test.strictEqual(result[3], false, 'table should not exist after dropped');
			test.done();
		}
	);
}
