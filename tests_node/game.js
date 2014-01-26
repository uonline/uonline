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

var usedTables = ['locations', 'uniusers', 'areas', 'monsters', 'monster_prototypes'].join(', ');

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
function creationAreasTableCallback(callback) {
	conn.query('CREATE TABLE areas ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`title` TINYTEXT'+
		' )', callback);
}
function creationUniusersTableCallback(callback) {
	conn.query('CREATE TABLE uniusers ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`location` INT DEFAULT 1,'+
		'`user` TINYTEXT,'+
		'`sessid` TINYTEXT,'+
		'`sessexpire` DATETIME,'+
		'`fight_mode` INT DEFAULT 0,'+
		'`autoinvolved_fm` INT DEFAULT 0, '+
		'`level` INT DEFAULT 1, '+
		'`health` INT DEFAULT 200, '+
		'`health_max` INT DEFAULT 200, '+
		'`mana` INT DEFAULT 100, '+
		'`mana_max` INT DEFAULT 100, '+
		'`energy` INT DEFAULT 50, '+
		'`power` INT DEFAULT 3, '+
		'`defense` INT DEFAULT 3, '+
		'`agility` INT DEFAULT 3, '+ //ловкость
		'`accuracy` INT DEFAULT 3, '+ //точность
		'`intelligence` INT DEFAULT 5, '+ //интеллект
		'`initiative` INT DEFAULT 5, '+ //инициатива
		'`exp` INT DEFAULT 0 )', callback);
}
function creationMonstersTableCallback(callback) {
	conn.query('CREATE TABLE monsters ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`prototype` INT,'+
		'`location` INT DEFAULT 1,'+
		'`attack_chance` INT )', callback);
}
function creationMonsterProtoTableCallback(callback) {
	conn.query('CREATE TABLE monster_prototypes ('+
		'`id` INT, PRIMARY KEY (`id`),'+
		'`name` TINYTEXT )', callback);
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

exports.getDefaultLocation = {
	'good test': function (test) {
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
	},
	'bad test': function (test) {
		async.series([
				creationLocationsTableCallback,
				insertCallback('locations', { "id": 1 } ),
				insertCallback('locations', { "id": 2 } ),
				insertCallback('locations', { "id": 3 } ),
				function(callback){ game.getDefaultLocation(conn, callback); },
			],
			function(error, result) {
				test.ok(!!error, 'should return error if default location is not defined');
				test.done();
			}
		);
	},
	'ambiguous test': function (test) {
		async.series([
				creationLocationsTableCallback,
				insertCallback('locations', {"id":1}),
				insertCallback('locations', {"id":2, "`default`":1}),
				insertCallback('locations', {"id":3, "`default`":1}),
				insertCallback('locations', {"id":4}),
				function(callback){ game.getDefaultLocation(conn, callback); },
			],
			function(error, result) {
				test.ok(!!error, 'should return error if there is more than one default location');
				test.done();
			}
		);
	},
};

exports.getUserLocationId = {
	"testValidData": function(test) {
		async.series([
				creationUniusersTableCallback,
				insertCallback('uniusers', {"id":1, "location":3}),
				insertCallback('uniusers', {"id":2, "location":1}),
				function(callback){ game.getUserLocationId(conn, 1, callback); },
				function(callback){ game.getUserLocationId(conn, 2, callback); },
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
				function(callback) {game.getUserLocationId(conn, -1, callback);},
			],
			function(error, result) {
				test.strictEqual(error, "Wrong user's id", 'should fail on wrong sessid');
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
				function(callback){ game.getUserLocation(conn, 1, callback); },
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
		game.getUserLocation(conn, -1, function(error, result) {
			test.strictEqual(error, "Wrong user's id", 'should fail on wrong id');
			test.done();
		});
	},
	"testWrongLocid": function(test) {
		async.series([
				insertCallback('locations', {"id":1, "area":5}),
				function(callback){ game.getUserLocation(conn, 1, callback); },
			],
			function(error, result) {
				test.ok(error, 'should fail if user.location is wrong');
				test.done();
			}
		);
	}
};

exports.getUserArea = {
	"setUp": function(callback) {
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				creationAreasTableCallback,
				insertCallback('uniusers', {"id":1, "location":3, "sessid":"someid"})
			], callback);
	},
	'usual test': function(test) {
		async.series([
				insertCallback('locations', {
					"id":3, "area":5, "title":"The Location", "goto":"Left=7|Forward=8|Right=9"}),
				insertCallback('areas', {
					"id":5, "title":"London"}),
				function(callback){ game.getUserArea(conn, 1, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[2].id, 5, "should return user's area id");
				test.strictEqual(result[2].title, 'London', "should return user's area name");
				test.done();
			}
		);
	},
	'wrong user id': function(test) {
		game.getUserArea(conn, -1, function(error, result) {
			test.strictEqual(error, "Wrong user's id", 'should fail on wrong id');
			test.done();
		});
	},
};

exports.changeLocation = {
	"setUp": function(callback) {
		async.series([
				creationUniusersTableCallback,
				creationLocationsTableCallback,
				creationMonstersTableCallback,
				insertCallback('uniusers', {"id":1, "location":1}),
				insertCallback('locations', {"id":1, "goto":"Left=2"}),
				insertCallback('locations', {"id":2, "goto":"Right=3"}),
				insertCallback('locations', {"id":3})
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				insertCallback('monsters', {"id":1, "location":2, "attack_chance":-1}),
				insertCallback('monsters', {"id":2, "location":3, "attack_chance":100}),
				function(callback){ game.changeLocation(conn, 1, 2, callback); },
				function(callback){ game.getUserLocationId(conn, 1, callback); },
				function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE id=1', callback); },
				function(callback){ game.changeLocation(conn, 1, 3, callback); },
				function(callback){ game.getUserLocationId(conn, 1, callback); },
				function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE id=1', callback); }
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
				function(callback){ game.changeLocation(conn, 1, 3, callback); },
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
			insertCallback('uniusers', {"id":1, "fight_mode":0}),
			function(callback){ game.goAttack(conn, 1, callback); },
			function(callback){ conn.query('SELECT fight_mode FROM uniusers WHERE id=1', callback); },
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
			insertCallback('uniusers', {"id":1, "fight_mode":1, "autoinvolved_fm":1}),
			function(callback){ game.goEscape(conn, 1, callback); },
			function(callback){ conn.query(
				'SELECT fight_mode, autoinvolved_fm FROM uniusers WHERE id=1', callback); },
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
				insertCallback('uniusers', {"id":1, "user":"someuser",  "location":1, "sessexpire":expire}),
				insertCallback('uniusers', {"id":2, "user":"otheruser", "location":1, "sessexpire":expire}),
				insertCallback('uniusers', {"id":3, "user":"thirduser", "location":1, "sessexpire":expire}),
				insertCallback('uniusers', {"id":4, "user":"aloneuser", "location":2, "sessexpire":expire}),
				insertCallback('locations', {"id":1}),
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				function(callback){ game.getNearbyUsers(conn, 1, 1, callback); },
				function(callback){ game.getNearbyUsers(conn, 4, 2, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.deepEqual(result[0], [
					{id:2, user:'otheruser'},
					{id:3, user:'thirduser'}], 'should return all other users on this location');
				test.deepEqual(result[1], [], 'alone user should be alone. for now');
				test.done();
			}
		);
	},
};

exports.getNearbyMonsters = function(test) {
	async.series([
			creationUniusersTableCallback,//0
			insertCallback('uniusers', {"id":1, "location":1}),
			insertCallback('uniusers', {"id":2, "location":2}),
			creationMonsterProtoTableCallback,
			insertCallback('monster_prototypes', {"id":1, "name":"The Creature of Unimaginable Horror"}),
			creationMonstersTableCallback,//5
			insertCallback('monsters', {"id":1, "prototype":1, "location":1, "attack_chance":42}),
			insertCallback('monsters', {"id":2, "prototype":1, "location":2}),
			insertCallback('monsters', {"id":3, "prototype":1, "location":2}),
			function(callback){ game.getNearbyMonsters(conn, 1, callback); }
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[9].length, 1, "should not return excess monsters");
			test.strictEqual(result[9][0].attack_chance, 42, "should return monster's info");
			test.strictEqual(result[9][0].name, "The Creature of Unimaginable Horror",
				"should return prototype info too");
			test.done();
		}
	);
};

exports.isInFight = function(test) {
	async.series([
			creationUniusersTableCallback,
			insertCallback('uniusers', {"id":2, "fight_mode":0}),
			insertCallback('uniusers', {"id":4, "fight_mode":1}),
			function(callback){ game.isInFight(conn, 2, callback); },
			function(callback){ game.isInFight(conn, 4, callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3], false, 'should return false if user is not in fight mode');
			test.strictEqual(result[4], true, 'should return true if user is in fight mode');
			test.done();
		}
	);
};

exports.isAutoinvolved = function(test) {
	async.series([
			creationUniusersTableCallback,
			insertCallback('uniusers', {"id":2, "fight_mode":1, "autoinvolved_fm":0}),
			insertCallback('uniusers', {"id":4, "fight_mode":1, "autoinvolved_fm":1}),
			function(callback){ game.isAutoinvolved(conn, 2, callback); },
			function(callback){ game.isAutoinvolved(conn, 4, callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3], false, 'should return false if user was not attacked');
			test.strictEqual(result[4], true, 'should return true if user was attacked');
			test.done();
		}
	);
};

exports.uninvolve = function(test) {
	async.series([
			creationUniusersTableCallback,
			insertCallback('uniusers', {"id":1, "fight_mode":1, "autoinvolved_fm":1}),
			function(callback){ game.uninvolve(conn, 1, callback); },
			function(callback){ conn.query(
				'SELECT fight_mode, autoinvolved_fm FROM uniusers WHERE id=1', callback); },
		],
		function(error, result) {
			test.ifError(error);
			test.strictEqual(result[3].rows[0].fight_mode, 1, 'should not disable fight mode');
			test.strictEqual(result[3].rows[0].autoinvolved_fm, 0, 'user should not be autoinvolved');
			test.done();
		}
	);
};

exports.getUserCharacters = {
	'testNoErrors': function(test) {
		async.series([
				creationUniusersTableCallback,
				insertCallback('uniusers', {
					id: 1,
					fight_mode: 1, autoinvolved_fm: 1,
					health: 100,   health_max: 200,
					mana: 50,      mana_max: 200,
					exp: 1000,     level: 2,
					energy: 128,
					power: 1,
					defense: 2,
					agility: 3,
					accuracy: 4,
					intelligence: 5,
					initiative: 6
				}),
				function(callback){ game.getUserCharacters(conn, 1, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.deepEqual(result[2], {
					health: 100,   health_max: 200,    health_percent: 50,
					mana: 50,      mana_max: 200,      mana_percent: 25,
					level: 2,
					exp: 1000,     exp_max: 3000,      exp_percent: 0,
					energy: 128,
					power: 1,
					defense: 2,
					agility: 3,
					accuracy: 4,
					intelligence: 5,
					initiative: 6
				}, "should return specific fields");
				test.done();
			}
		);
	},
	'testErrors': function(test) {
		game.getUserCharacters(conn, 1, function(error, result) {
			test.ok(error);
			test.done();
		});
	},
};

