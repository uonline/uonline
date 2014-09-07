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


// Converts location ways from string representation to array.
// For example:
// "Left=1|Middle=2|Right=42"
//   to
// [{target:1, text:"Left"}, {target:2, text:"Middle"}, {target:42, text:"Right"}]
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

// Returns id of location where users must be sent by default
// (after creation, in case of some errors, ...).
exports.getInitialLocation = function(dbConnection) {
	var result = dbConnection.query.sync(dbConnection, 'SELECT * FROM locations WHERE initial = 1');
	if (result.rows.length === 0)
	{
		throw new Error('initial location is not defined');
	}
	if (result.rows.length > 1)
	{
		throw new Error('there is more than one initial location');
	}
	var res = result.rows[0];
	res.ways = parseLocationWays(res.ways);
	return res;
}.async();

// Returns id of user's current location.
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

// Returns all attributes of user's current location.
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

// Returns all attributes of user's current area.
exports.getUserArea = function(dbConnection, userid) {
	var result = dbConnection.query.sync(
		dbConnection,
		'SELECT areas.* FROM areas, locations, uniusers '+
		'WHERE uniusers.id=$1 AND locations.id = uniusers.location AND areas.id = locations.area',
		[userid]);
	
	if (result.rows.length === 0)
	{
		throw new Error("Wrong user's id");
	}
	
	return result.rows[0];
}.async();

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

// Returns wheter user can go to specified location.
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

// Creates battle on location between two groups of creatures.
// @param [Transaction] tx already started transaction object
// @param [int] locid id of location
// @param [Array] firstSide array of objects describing participants like
// {
//   id: 1, // id of user/monster
//   kind: "user", // or "monster"
//   initiative: 12, // initiative of user or monster
// }
// @param [Array] secondSide same as firstSide
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

// Changes user location and starts (maybe) battle with some monsters.
exports.changeLocation = function(dbConnection, userid, locid) {
	var tx = transaction(dbConnection);
	
	var monsters = tx.query.sync(tx,
		"SELECT monsters.id, monsters.initiative, monsters.attack_chance "+
		"FROM uniusers, monsters "+
		"WHERE uniusers.id = $1 "+
			"AND monsters.location = $2 "+
			"AND NOT EXISTS ("+
				"SELECT 1 FROM battle_participants "+
				"WHERE kind = 'monster' AND id = monsters.id) "+
		"FOR UPDATE",
		[userid, locid]).rows;
	
	var pouncedMonsters = monsters.some(function(m){return Math.random()*100 <= m.attack_chance;}) ? monsters : [];
	
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
			(pouncedMonsters.length > 0 ? ', autoinvolved_fm = 1' : '')+
			' WHERE id = $2',
			[locid, userid]);
	
	tx.commit.sync(tx);
	
}.async();

// Starts battle with monsters on current location.
exports.goAttack = function(dbConnection, userid) {
	var tx = transaction(dbConnection);
	
	var monsters = tx.query.sync(tx,
		'SELECT monsters.id, monsters.initiative '+
		'FROM uniusers, monsters '+
		'WHERE uniusers.id = $1 '+
			'AND monsters.location = uniusers.location '+
			'AND ('+
				'SELECT count(*) FROM battle_participants '+ //prevents starting second battle
				"WHERE kind='user' AND id=$1) = 0 "+
		'FOR UPDATE',
		[userid]).rows;
	if (monsters.length === 0)
	{
		tx.rollback.sync(tx);
		return;
	}
	
	for (var i=0; i<monsters.length; i++)
	{
		monsters[i].kind = 'monster';
	}
	
	var user = tx.query.sync(tx,
		'SELECT initiative, location FROM uniusers WHERE id = $1', [userid]).rows[0];
	user.id = userid;
	user.kind = 'user';
	
	exports.createBattleBetween.sync(null, tx, user.location, monsters, [user]);
	
	tx.commit.sync(tx);
}.async();

// Escapes user from battle.
exports.goEscape = function(dbConnection, userid) {
	var tx = transaction(dbConnection);
	
	var result = tx.query.sync(tx,
		"SELECT battle FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE", [userid]);
	
	if (result.rows.length !== 0)
	{
		var battleId = result.rows[0].battle;
		tx.query.sync(tx, 'DELETE FROM battle_participants WHERE battle = $1', [battleId]);
		tx.query.sync(tx, 'DELETE FROM battles WHERE id = $1', [battleId]);
	}
	
	tx.query.sync(tx, 'UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1', [userid]);
	
	tx.commit.sync(tx);
}.async();

// Returns user's battle participants as array of objects like
// {
//    id: 1, // id of user/monster
//    kind: "user", // or "monster"
//    name: "Vasya", // user's username or monster's name
//    index: 3, // turn number, starts from 0
//    side: 0, // side in battle, 0 or 1
// }
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

exports.hitOpponent = function(dbConnection, userid, participantIndex) {
	var tx = transaction(dbConnection);
	
	var user = tx.query.sync(tx,
		"SELECT battle_participants.battle, battle_participants.side, uniusers.power "+
		"FROM uniusers, battles, battle_participants "+
		"WHERE uniusers.id = $1 "+
			"AND battle_participants.id = $1 "+
			"AND battle_participants.kind='user' "+
			"AND battles.id = battle_participants.battle "+
		"FOR UPDATE",
		[userid]).rows[0];
	// check?
	console.log(user)
	
	var targetParticipant = tx.query.sync(tx,
		"SELECT battle_participants.id, battle_participants.kind, battle_participants.index "+
		"FROM uniusers, battles, battle_participants "+
		"WHERE battle_participants.index = $1 "+
			"AND battle_participants.battle = $2"+
			"AND battle_participants.side = $3",
		[participantIndex, user.battle, 1-user.side]).rows[0];
	console.log(targetParticipant, participantIndex, user.battle, 1-user.side)
	
	if (targetParticipant === undefined)
	{
		tx.rollback.sync(tx);
		return;
	}
	
	var health;
	switch(targetParticipant.kind)
	{
	case 'user':
		health = tx.query.sync(tx,
			"UPDATE uniusers "+
			"SET health = health - GREATEST(0, $1-defense)/2 * (0.8+RANDOM()*0.4) "+
			"WHERE id = $2 "+
			"RETURNING health",
			[user.power, targetParticipant.id]).rows[0].health;
		break;
	case 'monster':
		health = tx.query.sync(tx,
			"UPDATE monsters "+
			"SET health = health - GREATEST(0, $1-protos.defense)/2 * (0.8+RANDOM()*0.4) "+
			"FROM monster_prototypes AS protos "+
			"WHERE monsters.id = $2 "+
				"AND protos.id = monsters.prototype "+
			"RETURNING monsters.health",
			[user.power, targetParticipant.id]).rows[0].health;
		break;
	default:
		tx.rollback.sync(tx);
		throw new Error('Wrong participant kind: '+targetParticipant.kind);
	}
	console.log(health)
	
	if (health <= 0)
	{
		tx.query.sync(tx,
			"DELETE FROM battle_participants "+
			"WHERE id = $1 AND kind = $2",
			[targetParticipant.id, targetParticipant.kind]);
		
		tx.query.sync(tx,
			"UPDATE battle_participants "+
			"SET index = index - 1 "+
			"WHERE battle = $1 AND index > $2",
			[user.battle, targetParticipant.index]);
		
		switch(targetParticipant.kind)
		{
		case 'monster':
			tx.query.sync(tx,
				"DELETE FROM monsters WHERE id = $1", [targetParticipant.id]);
			break;
		case 'user':
			tx.query.sync(tx,
				"UPDATE uniusers "+
				"SET health = health_max, "+
				"    location = (SELECT id FROM locations WHERE initial = 1) "+
				"WHERE id = $1", 
				[targetParticipant.id]);
			break;
		}
		
		var opponentsCount = +tx.query.sync(tx,
			"SELECT count(*) FROM battle_participants "+
			"WHERE battle = $1 AND side = $2 ", [user.battle, 1-user.side]).rows[0].count;
		
		if (opponentsCount === 0)
		{
			tx.query.sync(tx, "DELETE FROM battle_participants WHERE battle = $1", [user.battle]);
			tx.query.sync(tx, "DELETE FROM battles WHERE id = $1", [user.battle]);
			tx.query.sync(tx, "UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1", [userid]);
		}
	}
	
	tx.commit.sync(tx);
}.async();

// Returns id and username of users on specified location.
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

// Returns all users on locations except one.
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

// Select nearby monsters with their characteristics (both from monsters and their prototypes)
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

// Checks if user is in battle.
exports.isInFight = function(dbConnection, userid) {
	return dbConnection.query.sync(dbConnection,
		"SELECT count(*) FROM battle_participants "+
		"WHERE kind = 'user' AND id = $1", [userid]).rows[0].count > 0;
}.async();

// Checks if user was just involved in battle.
exports.isAutoinvolved = function(dbConnection, userid, callback) {
	dbConnection.query("SELECT autoinvolved_fm FROM uniusers WHERE id = $1", [userid],
		function (error, result) {
			callback(error, error || (result.rows[0].autoinvolved_fm == 1));
		}
	);
};

// Clears user's "just envolved" mark.
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
// Returns users's characteristics by id or name.
exports.getUserCharacters = function(dbConnection, userIdOrName) {
	var field = typeof userIdOrName === 'number' ? 'id' : 'username';
	var user = dbConnection.query.sync(dbConnection,
		'SELECT '+joinedCharacters+' FROM uniusers WHERE '+field+' = $1', [userIdOrName]).rows[0];
	
	if (user === undefined)
	{
		return null;
	}
	
	user.health_percent = user.health * 100 / user.health_max;
	user.mana_percent = user.mana * 100 / user.mana_max;
	var expPrevMax = math.ap(config.EXP_MAX_START, user.level-1, config.EXP_STEP);
	user.exp_max = math.ap(config.EXP_MAX_START, user.level, config.EXP_STEP);
	user.exp_percent = (user.exp-expPrevMax) * 100 / (user.exp_max-expPrevMax);
	//user['nickname'] = user['user']; //лучше поле 'user' переименовать
	return user;
}.async();


