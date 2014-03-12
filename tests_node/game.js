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

var game = require('../lib-cov/game');

var mg = require('../lib/migration');

var async = require('async');

var anyDB = require('any-db');
var conn = null;

var usedTables = ['locations', 'uniusers', 'areas', 'monsters', 'monster_prototypes'].join(', ');

exports.setUp = function (done) {
	async.series([
		function(callback) {
			conn = anyDB.createConnection(config.DATABASE_URL_TEST);
			conn.query("DROP TABLE IF EXISTS "+usedTables, callback);
		},
	], done);
};

exports.tearDown = function (done) {
	async.series([
		function(callback) {
			conn.query("DROP TABLE IF EXISTS "+usedTables, callback);
		},
		function(callback) {
			conn.end();
			callback();
		}
	], done);
};


function insertCallback(dbName, fields) { //НЕ для использования снаружи тестов
	var params=[], values=[];
	for (var i in fields) {
		params.push(i);
		values.push(typeof fields[i] === 'string' ? "'"+fields[i]+"'" : fields[i]);
	}
	var query = 'INSERT INTO '+dbName+' ('+params.join(', ')+') VALUES ('+values.join(', ')+')';
	return function(callback) {
		//console.log(query);
		conn.query(query, function(e,r) {
			//console.log("done", e);
			callback(e,r);
		});
	};
}

exports.getDefaultLocation = {
	'good test': function (test) {
		async.series([
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
				insertCallback('locations', {"id":1}),
				insertCallback('locations', {"id":2, '"default"':1}),
				insertCallback('locations', {"id":3}),
				function(callback){ game.getDefaultLocation(conn, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.strictEqual(result[4].id, 2, 'should return id of default location');
				test.ok(result[4].goto instanceof Array, 'should return parsed ways from location');
				test.done();
			}
		);
	},
	'bad test': function (test) {
		async.series([
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
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
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
				insertCallback('locations', {"id":1}),
				insertCallback('locations', {"id":2, '"default"':1}),
				insertCallback('locations', {"id":3, '"default"':1}),
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
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				insertCallback('uniusers', {"id":1, '"location"':3}),
				insertCallback('uniusers', {"id":2, '"location"':1}),
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
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				function(callback) {game.getUserLocationId(conn, -1, callback);},
			],
			function(error, result) {
				test.ok(error, 'should fail on wrong sessid');
				test.done();
			}
		);
	}
};

exports.getUserLocation = {
	"setUp": function(callback) {
		async.series([
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
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
			test.ok(error, 'should fail on wrong id');
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
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'areas', callback); },
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
			test.ok(error, 'should fail on wrong id');
			test.done();
		});
	},
};

exports.changeLocation = {
	"setUp": function(callback) {
		async.series([
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'monsters', callback); },
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
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
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
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
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
		var now = (d.getFullYear()+1)+'-'+(d.getMonth()+1)+'-'+d.getDate();
		async.series([
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				function(callback){ mg.migrate(conn, Infinity, 'locations', callback); },
				insertCallback('uniusers', {"id":1, '"user"':"someuser",  "location":1, "sess_time":now}),
				insertCallback('uniusers', {"id":2, '"user"':"otheruser", "location":1, "sess_time":now}),
				insertCallback('uniusers', {"id":3, '"user"':"thirduser", "location":1, "sess_time":now}),
				insertCallback('uniusers', {"id":4, '"user"':"AFKuser",   "location":1, "sess_time":"1980-01-01"}),
				insertCallback('uniusers', {"id":5, '"user"':"aloneuser", "location":2, "sess_time":now}),
				insertCallback('locations', {"id":1}),
			], callback);
	},
	"testValidData": function(test) {
		async.series([
				function(callback){ game.getNearbyUsers(conn, 1, 1, callback); },
				function(callback){ game.getNearbyUsers(conn, 5, 2, callback); },
			],
			function(error, result) {
				test.ifError(error);
				test.deepEqual(result[0], [
					{id:2, user:'otheruser'},
					{id:3, user:'thirduser'}], 'should return all online users on this location');
				test.deepEqual(result[1], [], 'alone user should be alone. for now');
				test.done();
			}
		);
	},
};

exports.getNearbyMonsters = function(test) {
	async.series([
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },//0
			insertCallback('uniusers', {"id":1, "location":1}),
			insertCallback('uniusers', {"id":2, "location":2}),
			function(callback){ mg.migrate(conn, Infinity, 'monster_prototypes', callback); },
			insertCallback('monster_prototypes', {"id":1, "name":"The Creature of Unimaginable Horror"}),
			function(callback){ mg.migrate(conn, Infinity, 'monsters', callback); },//5
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
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
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
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
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
			function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
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
				function(callback){ mg.migrate(conn, Infinity, 'uniusers', callback); },
				insertCallback('uniusers', {
					id: 1,
					'"user"': 'someuser',
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
				function(callback){ game.getUserCharacters(conn, 'someuser', callback); },
				function(callback){ game.getUserCharacters(conn, 2, callback); },
				function(callback){ game.getUserCharacters(conn, 'anotheruser', callback); },
			],
			function(error, result) {
				test.ifError(error);
				var expectedData = {
					id: 1,
					user: 'someuser',
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
				};
				test.deepEqual(result[2], expectedData, "should return specific fields by id");
				test.deepEqual(result[3], expectedData, "should return specific fields by nickname");
				test.strictEqual(result[4], null, "should return null if no such user exists");
				test.strictEqual(result[5], null, "should return null if no such user exists");
				test.done();
			}
		);
	},
	'testErrors': function(test) {
		game.getUserCharacters(conn, 1, function(error, result) {
			test.ok(!!error);
			test.done();
		});
	},
};

