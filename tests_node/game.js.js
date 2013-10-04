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


function creationLocationsTableCallback(callback) {
	conn.query('CREATE TABLE locations ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`title` TINYTEXT,'+
		'`goto` TINYTEXT,'+
		//'`description` TEXT,'+
		'`area` INT,'+
		'`default` TINYINT(1) DEFAULT 0 )', callback);
}
function creationUniusersTableCallback(callback) {
	conn.query('CREATE TABLE uniusers ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`location` INT DEFAULT 1,'+
		'`sessid` TINYTEXT )', callback);
}
function insertCallback(dbName, fields) { //НЕ для использования снаружи тестов
	var params=[], values=[];
	for (var i in fields) {
		params.push(i);
		values.push(JSON.stringify(fields[i]));
	}
	var query = 'INSERT INTO '+dbName+' ('+params.join(', ')+') VALUES ('+values.join(', ')+')';
	return function(callback) {conn.query(query, callback);};
}

exports.getDefaultLocation = function (test) {
	async.series([
			creationLocationsTableCallback,
			insertCallback('locations', {"id":1}),
			insertCallback('locations', {"id":2, "`default`":1}),
			insertCallback('locations', {"id":3}),
			function(callback){ game.getDefaultLocation(conn, callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[4].id, 2, 'should return id of default location');
			test.done();
		}
	);
};

exports.getUserLocationId = {
	"testValidData": function(test) {
		async.series([
				creationUniusersTableCallback,
				insertCallback('uniusers', {"id":1, "location":3, "sessid":"qweasd"}),
				insertCallback('uniusers', {"id":2,               "sessid":"asdzxc"}),
				function(callback){ game.getUserLocationId(conn, "qweasd", callback); },
				function(callback){ game.getUserLocationId(conn, "asdzxc", callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[3], 3, 'should return user\'s location id');
				test.strictEqual(result[4], 1, 'should return user\'s location id');
				test.done();
			}
		);
	},
	"testWrongSessid": function(test) {
		async.series([
				creationUniusersTableCallback,
				function(callback) {game.getUserLocationId(conn, "no_such_sessid", callback);},
			],
			function(error, result) {
				test.ok(error);
				test.done();
			}
		);
	}
};

exports.getUserLocation = {
	"setUp": function(callback) {
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				insertCallback('uniusers', {"id":1, "location":3, "sessid":"someid"})
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				insertCallback('locations', {
					"id":3, "area":5, "title":"The Location", "goto":"Left=7|Forward=8|Right=9"}),
				function(callback){ game.getUserLocation(conn, "someid", callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[1].id, 3, 'should return user\'s location id');
				test.strictEqual(result[1].goto.length, 3, 'there should be 3 ways out');
				test.strictEqual(result[1].goto[0].text, 'Left',  'should return first way name');
				test.strictEqual(result[1].goto[0].id,   '7',     'should return first way id');
				test.strictEqual(result[1].goto[1].text, 'Forward', 'should return second way name');
				test.strictEqual(result[1].goto[1].id,   '8',     'should return second way id');
				test.strictEqual(result[1].goto[2].text, 'Right', 'should return third wayname');
				test.strictEqual(result[1].goto[2].id,   '9',     'should return third way id');
				test.done();
			}
		);
	},
	"testWrongSessid": function(test) {
		game.getUserLocation(conn, 'no_such_sessid', function(error, result) {
			test.ok(error, 'should fail on wrong sessid');
			test.done();
		});
	},
	//а поидее, надо проверять валидность локаци при переходе юзера на неё, и тут это не должно имень смысла
	"testWrongLocid": function(test) {
		async.series([
				insertCallback('locations', {"id":1, "area":5}),
				function(callback){ game.getUserLocation(conn, "someid", callback); },
			],
			function(error, result) {
				test.ok(error, 'should fail if user.location is wrong');
				test.done();
			}
		);
	}
};

/*exports.changeLocation = {
	"setUp": function(callback) {
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				insertCallback('uniusers', {"id":1, "location":3, "sessid":"someid"})
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				insertCallback('locations', {"id":3}),
				function(callback){ game.changeLocation(conn, "someid", 3, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.done();
			}
		);
	},
}*/

