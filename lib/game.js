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

var sync = require('sync');
var config = require('../config.js');
var math = require('./math.js');
var transaction = require('any-db-transaction');


function parseLocationWays(str) {
	if (str === null) return [];
	var ways = str.split("|");
	for (var i=0; i<ways.length; i++)
	{
		var s = ways[i].split("=");
		ways[i] = {target: parseInt(s[1], 10), text: s[0]};
	}
	return ways;
}

exports.getDefaultLocation = function(dbConnection) {
	var result = dbConnection.query.sync(dbConnection, 'SELECT * FROM locations WHERE initial = 1');
	if (result.rows.length === 0)
	{
		throw new Error('default location is not defined');
	}
	if (result.rows.length > 1)
	{
		throw new Error('there is more than one default location');
	}
	var res = result.rows[0];
	res.ways = parseLocationWays(res.ways);
	return res;
}.async();

exports.getUserLocationId = function(dbConnection, userid, callback) {
	dbConnection.query(
		'SELECT location FROM uniusers WHERE id = $1',
		[userid],
		function (error, result) {
			if (!!result && result.rows.length === 0)
			{
				error = new Error("Wrong user's id");
			}
			callback(error, error || result.rows[0].location);
		}
	);
};

exports.getUserLocation = function(dbConnection, userid) {
	var result = dbConnection.query.sync(
		dbConnection,
		'SELECT locations.* FROM locations, uniusers '+
		'WHERE uniusers.id=$1 AND locations.id = uniusers.location',
		[userid]);

	if (result.rows.length === 0)
	{
		throw new Error("Wrong user's id or location");
	}

	var res = result.rows[0];
	res.ways = parseLocationWays(res.ways);

	return res;
}.async();

exports.getUserArea = function(dbConnection, userid, callback) {
	dbConnection.query(
		'SELECT areas.* FROM areas, locations, uniusers '+
		'WHERE uniusers.id=$1 AND locations.id = uniusers.location AND areas.id = locations.area',
		[userid],
		function (error, result) {
			if (!!result && result.rows.length === 0)
			{
				error = new Error("Wrong user's id");
			}
			if (!!error)
			{
				callback(error, null);
				return;
			}
			var res = result.rows[0];
			callback(null, res);
		}
	);
};

/*exports.getAllowedZones = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT locations.goto FROM locations, uniusers '+
		'WHERE uniusers.sessid = ? AND locations.id = uniusers.location AND uniusers.fight_mode = 0',
		[sessid],
		function (error, result) {
			if (!!error) {callback(error, null); return;}
			var a = result.rows[0].goto.split("|");
			for (var i=0;i<a.length;i++) {
				var s = a[i].split("=");
				a[i] = {to: s[1], name: s[0]};
			}
			callback(null, a);
		}
	);
};*/

exports.canChangeLocation = function(dbConnection, userid, locid) {
	var result = exports.getUserLocation.sync(null, dbConnection, userid);
	if (result.id == locid) return false; // already here

	for (var i in result.ways)
	{
		if (result.ways[i].target == locid)
		{
			return true;
		}
	}

	return false;
}.async();

exports.createBattleBetween = function(tx, locid, firstSide, secondSide) {
	var newBattleId = tx.query.sync(tx,
		'INSERT INTO battles (location) VALUES ($1) RETURNING id', [locid]).rows[0].id;
	
	var participants = firstSide.map(function(p){ p.side=0; return p; })
		.concat(secondSide.map(function(p){ p.side=1; return p; }))
		.sort(function(a,b){ return b.initiative - a.initiative; });
	
	tx.query.sync(tx,
		'INSERT INTO battle_participants (battle, id, kind, index, side) VALUES '+
			participants.map(function(p,i) {
				return "("+newBattleId+", "+p.id+", '"+p.kind+"', "+i+", "+p.side+")";
			}).join(", "));
	
	return newBattleId;
}.async();

exports.changeLocation = function(dbConnection, userid, locid) {
	var tx = transaction(dbConnection);
	
	var pouncedMonsters = tx.query.sync(tx,
		"SELECT monsters.id, monsters.initiative "+
		"FROM uniusers, monsters "+
		"WHERE uniusers.id = $1 "+
			"AND monsters.location = $2 "+
			"AND RANDOM()*100 <= monsters.attack_chance "+
			"AND NOT EXISTS ("+
				"SELECT 1 FROM battle_participants "+
				"WHERE kind = 'monster' AND id = monsters.id) "+
		"FOR UPDATE",
		[userid, locid]).rows;
	
	if (pouncedMonsters.length > 0)
	{
		pouncedMonsters.forEach(function(m){ m.kind = 'monster'; });
		
		var user = {
			id: userid,
			initiative: tx.query.sync(tx,
				'SELECT initiative FROM uniusers WHERE id = $1', [userid]).rows[0].initiative,
			kind: 'user',
		};
		
		exports.createBattleBetween.sync(null, tx, locid, pouncedMonsters, [user]);
	}
	
	tx.query.sync(tx,
			'UPDATE uniusers SET location = $1'+
			(pouncedMonsters.length > 0 ? ', autoinvolved_fm = 1, fight_mode = 1' : '')+
			' WHERE id = $2',
			[locid, userid]);
	
	tx.commit.sync(tx);
	
}.async();

exports.goAttack = function(dbConnection, userid) {
	var tx = transaction(dbConnection);
	
	var target = tx.query.sync(tx,
		'SELECT monsters.id, monsters.initiative '+
		'FROM uniusers, monsters '+
		'WHERE uniusers.id = $1 AND monsters.location = uniusers.location '+
		'FOR UPDATE',
		[userid]).rows[0];
	if (target === undefined)
	{
		tx.rollback.sync(tx);
		return;
	}
	target.kind = 'monster';
	
	var user = tx.query.sync(tx,
		'SELECT initiative, location FROM uniusers WHERE id = $1', [userid]).rows[0];
	user.id = userid;
	user.kind = 'user';
	
	exports.createBattleBetween.sync(null, tx, user.location, [target], [user]);
	
	tx.query.sync(tx, 'UPDATE uniusers SET fight_mode = 1 WHERE id = $1', [userid]);
	
	tx.commit.sync(tx);
}.async();

exports.goEscape = function(dbConnection, userid) {
	var tx = transaction(dbConnection);
	
	var result = tx.query.sync(tx,
		"SELECT battle FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE", [userid]);
	
	if (result.rows.length !== 0)
	{
		var battleId = result.rows[0].battle;
		tx.query.sync(tx, 'DELETE FROM battle_participants WHERE battle = $1', [battleId]);
		tx.query.sync(tx, 'UPDATE battles SET is_over = 1 WHERE id = $1', [battleId]);
	}
	
	tx.query.sync(tx, 'UPDATE uniusers SET fight_mode = 0, autoinvolved_fm = 0 WHERE id = $1', [userid]);
	
	tx.commit.sync(tx);
}.async();

exports.getBattleParticipants = function(dbConnection, userid) {
	var participants = dbConnection.query.sync(dbConnection,
		"SELECT id, kind, index, side FROM battle_participants "+
		"WHERE battle = ("+
			"SELECT battle from battle_participants "+
			"WHERE kind = 'user' AND id = $1) "+
		"ORDER BY index", [userid]).rows;
	
	for (var i=0; i<participants.length; i++)
	{
		var p = participants[i];
		
		switch (p.kind)
		{
		case 'user':
			p.name = dbConnection.query.sync(dbConnection,
				'SELECT username FROM uniusers WHERE id = $1', [p.id]).rows[0].username;
			break;
		case 'monster':
			p.name = dbConnection.query.sync(dbConnection,
				'SELECT monster_prototypes.name FROM monster_prototypes, monsters '+
				'WHERE monsters.id = $1 AND monster_prototypes.id = monsters.prototype', [p.id]).rows[0].name;
			break;
		default:
			throw new Error('Wrong participant kind: '+p.kind);
		}
	}
	
	return participants;
}.async();

exports.getUsersOnLocation = function(dbConnection, locid, callback) {
	dbConnection.query(
		'SELECT id, username FROM uniusers '+
		"WHERE sess_time > NOW() - $1 * INTERVAL '1 SECOND' AND location = $2",
		[config.userOnlineTimeout, locid],
		function(error, result) {
			callback(error, error || result.rows);
		}
	);
};

exports.getNearbyUsers = function(dbConnection, userid, locid, callback) {
	exports.getUsersOnLocation(
		dbConnection,
		locid,
		function(error, result) {
			if (!!error) callback(error, null);
			result = result.filter(function (i) {
				return i.id !== userid;
			});
			callback(null, result);
		}
	);
};

exports.getNearbyMonsters = function(dbConnection, locid, callback) {
	dbConnection.query(
		'SELECT monster_prototypes.*, monsters.* '+
		'FROM monster_prototypes, monsters '+
		'WHERE monsters.location = $1 '+
		'AND monster_prototypes.id = monsters.prototype',
		[locid],
		function(error, result) {
			callback(error, error || result.rows);
		}
	);
};

exports.isInFight = function(dbConnection, userid, callback) {
	dbConnection.query("SELECT fight_mode FROM uniusers WHERE id = $1", [userid], function (error, result) {
		callback(error, error || (result.rows[0].fight_mode == 1));
	});
};

exports.isAutoinvolved = function(dbConnection, userid, callback) {
	dbConnection.query("SELECT autoinvolved_fm FROM uniusers WHERE id = $1", [userid],
		function (error, result) {
			callback(error, error || (result.rows[0].autoinvolved_fm == 1));
		}
	);
};

exports.uninvolve = function(dbConnection, userid, callback) {
	dbConnection.query("UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1", [userid], callback);
};

var characters = [
	'id',
	'username',
	'health',
	'health_max',
	'mana',
	'mana_max',
	'energy',
	'power',
	'defense',
	'agility',
	'accuracy',
	'intelligence',
	'initiative',
	'exp',
	'level',
];
var joinedCharacters = characters.join(",");
exports.getUserCharacters = function(dbConnection, userIdOrName, callback) {
	var field = typeof userIdOrName === 'number' ? 'id' : 'username';
	dbConnection.query(
		'SELECT '+joinedCharacters+' FROM uniusers WHERE '+field+' = $1',
		[userIdOrName],
		function(error, result) {
			if (!!error)
			{
				callback(error, null);
				return;
			}
			var res = result.rows[0];
			if (res === undefined)
			{
				callback(null, null);
				return;
			}
			res.health_percent = res.health * 100 / res.health_max;
			res.mana_percent = res.mana * 100 / res.mana_max;
			var expPrevMax = math.ap(config.EXP_MAX_START, res.level-1, config.EXP_STEP);
			res.exp_max = math.ap(config.EXP_MAX_START, res.level, config.EXP_STEP);
			res.exp_percent = (res.exp-expPrevMax) * 100 / (res.exp_max-expPrevMax);
			//res['nickname'] = res['user']; //лучше поле 'user' переименовать
			callback(null, res);
		}
	);
};


