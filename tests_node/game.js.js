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

var usedTables = ['locations', 'uniusers', 'monsters'].join(', ');

exports.setUp = function (done) {
	async.series([
		function(callback) {
			conn = anyDB.createConnection(config.MYSQL_DATABASE_URL_TEST);
			conn.query("DROP TABLE IF EXISTS "+usedTables, callback);
		},
	], done);
};

exports.tearDown = function (done) {
	async.series([
		function(callback) {
			conn.query("DROP TABLE IF EXISTS "+usedTables, callback);
			conn.end();
		},
	], done);
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
		'`user` TINYTEXT,'+
		'`sessid` TINYTEXT,'+
		'`sessexpire` DATETIME,'+
		'`fight_mode` INT DEFAULT 0,'+
		'`autoinvolved_fm` INT DEFAULT 0 )', callback);
}
function creationMonstersTableCallback(callback) {
	conn.query('CREATE TABLE monsters ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`location` INT DEFAULT 1,'+
		'`attack_chance` INT )', callback);
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
				insertCallback('uniusers', {"id":2, "location":1, "sessid":"asdzxc"}),
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
	},
	"testWrongSessid": function(test) {
		async.series([
				creationUniusersTableCallback,
				function(callback) {game.getUserLocationId(conn, "no_such_sessid", callback);},
			],
			function(error, result) {
				test.strictEqual(error, "Wrong user's sessid", 'should fail on wrong sessid');
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
				test.strictEqual(result[1].id, 3, "should return user's location id");
				test.deepEqual(result[1].goto, [
					{id:7, text:'Left'},
					{id:8, text:'Forward'},
					{id:9, text:'Right'}], 'should return ways from location');
				test.done();
			}
		);
	},
	"testWrongSessid": function(test) {
		game.getUserLocation(conn, 'no_such_sessid', function(error, result) {
			test.strictEqual(error, "Wrong user's sessid", 'should fail on wrong sessid');
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

exports.changeLocation = {
	"setUp": function(callback) {
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				creationMonstersTableCallback,
				insertCallback('uniusers', {"id":1, "location":1, "sessid":"someid"}),
				insertCallback('locations', {"id":1, "goto":"Left=2"}),
				insertCallback('locations', {"id":2, "goto":"Right=3"}),
				insertCallback('locations', {"id":3})
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				insertCallback('monsters', {"id":1, "location":2, "attack_chance":-1}),
				insertCallback('monsters', {"id":2, "location":3, "attack_chance":100}),
				function(callback){ game.changeLocation(conn, "someid", 2, callback); },
				function(callback){ game.getUserLocationId(conn, "someid", callback); },
				function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE sessid="someid"', callback); },
				function(callback){ game.changeLocation(conn, "someid", 3, callback); },
				function(callback){ game.getUserLocationId(conn, "someid", callback); },
				function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE sessid="someid"', callback); }
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[3], 2, 'user shold have moved to new location');
				test.strictEqual(result[4].rows[0].fight_mode, 0, 'user should not be attacked');
				test.strictEqual(result[6], 3, 'user shold have moved to new location');
				test.strictEqual(result[7].rows[0].fight_mode, 1, 'user should be attacked');
				test.done();
			}
		);
	},
	"testWrongLocid": function(test) {
		async.series([
				function(callback){ game.changeLocation(conn, "someid", 3, callback); },
			],
			function(error, result) {
				test.ok(error, 'should fail if no way from current location to destination');
				test.done();
			}
		);
	}
};

exports.goAttack = function(test) {
	async.series([
			creationUniusersTableCallback,
			insertCallback('uniusers', {"id":1, "sessid":"someid", "fight_mode":0}),
			function(callback){ game.goAttack(conn, "someid", callback); },
			function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE sessid="someid"', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3].rows[0].fight_mode, 1, 'user should be attacking');
			test.done();
		}
	);
};

exports.goEscape = function(test) {
	async.series([
			creationUniusersTableCallback,
			insertCallback('uniusers', {"id":1, "sessid":"someid", "fight_mode":1, "autoinvolved_fm":1}),
			function(callback){ game.goEscape(conn, "someid", callback); },
			function(callback){ conn.query(
				'SELECT fight_mode, autoinvolved_fm FROM uniusers WHERE sessid="someid"', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3].rows[0].fight_mode, 0, 'user should not be attacking');
			test.strictEqual(result[3].rows[0].autoinvolved_fm, 0, 'user should not be autoinvolved');
			test.done();
		}
	);
};

exports.getNearbyUsers = {
	"setUp": function(callback) {
		var d = new Date();
		var expire = (d.getFullYear()+1)+'-'+(d.getMonth()+1)+'-'+d.getDate();
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				insertCallback('uniusers', {"id":1, "user":"user1", "location":1,
					"sessid":"someid", "sessexpire":expire}),
				insertCallback('uniusers', {"id":2, "user":"user2", "location":1,
					"sessid":"otherid", "sessexpire":expire}),
				insertCallback('uniusers', {"id":3, "user":"user3", "location":1,
					"sessid":"thirdid", "sessexpire":expire}),
				insertCallback('uniusers', {"id":4, "user":"alone", "location":2,
					"sessid":"aloneid", "sessexpire":expire}),
				insertCallback('locations', {"id":1}),
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				function(callback){ game.getNearbyUsers(conn, "someid", callback); },
				function(callback){ game.getNearbyUsers(conn, "aloneid", callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.deepEqual(result[0], [
					{id:2, user:'user2'},
					{id:3, user:'user3'}], 'should return all other users on this location');
				test.deepEqual(result[1], [], 'alone user should be alone. for now');
				test.done();
			}
		);
	},
	//TODO: finish this
//	"testWrongSessid": function(test) {
//		async.series([
//				function(callback) {game.getNearbyUsers(conn, "no_such_sessid", callback);},
//			],
//			function(error, result) {console.log(error, result)
//				test.ok(error);
//				test.done();
//			}
//		);
//	}
};


