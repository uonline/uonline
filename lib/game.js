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


// А вот эта штука может пригодиться, ибо что-то мне подсказывает,
// что вылетевший после transaction(dbConnection) эксепшен
// эту транзакцию нифига не отменит...
/*
function doInTransaction(dbConnection, func)
{
	var tx = transaction(dbConnection);
	try
	{
		func(tx);
	}
	catch (e)
	{
		if (tx.state() == 'open') tx.rollback();
		throw e;
	}
	if (tx.state() == 'open') tx.commit();
}
*/


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
exports.isTherePathForUserToLocation = function(dbConnection, userid, locid) {
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
exports._createBattleBetween = function(tx, locid, firstSide, secondSide) {
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
};


// Stops battle. Sets autoinvolved_fm to 0 for all involved users,
// destroys battle and all participant records.
exports._stopBattle = function(tx, battleId) {
	tx.query.sync(tx,
		'UPDATE uniusers SET autoinvolved_fm = 0 '+
		"WHERE id IN (SELECT id FROM battle_participants WHERE battle = $1 AND kind = 'user')",
		[battleId]);
	tx.query.sync(tx, "DELETE FROM battle_participants WHERE battle = $1", [battleId]);
	tx.query.sync(tx, "DELETE FROM battles WHERE id = $1", [battleId]);
};

// Makes someone (user or monster) to leave battle.
// If it is user, sets his autoinvolved_fm to 0.
// If he was last on his battle side, stops battle.
exports._leaveBattle = function(tx, battleId, leaverId, leaverKind) {
	// removing leaver's battle_participant
	var leaver = tx.query.sync(tx,
		"DELETE FROM battle_participants "+
		"WHERE id = $1 AND kind = $2 "+
		"RETURNING index, side",
		[leaverId, leaverKind]).rows[0];
	if (!leaver)
	{
		throw new Error("Can't find participant with id="+leaverId+
			" and kind='"+leaverKind+"' in battle with id="+battleId);
	}
	
	// shifting other participant's indexes
	tx.query.sync(tx,
		"UPDATE battle_participants "+
		"SET index = index - 1 "+
		"WHERE battle = $1 AND index > $2",
		[battleId, leaver.index]);
	
	if (leaverKind == 'user')
	{
		tx.query.sync(tx, "UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = $1", [leaverId]);
	}
	
	var teammatesCount = +tx.query.sync(tx,
		"SELECT count(*) FROM battle_participants "+
		"WHERE battle = $1 AND side = $2 ", [battleId, leaver.side]).rows[0].count;
	
	if (teammatesCount === 0)
	{
		exports._stopBattle(tx, battleId);
	}
	
	return teammatesCount === 0;
};


// Changes user location and starts (maybe) battle with some monsters.
exports.changeLocation = function(dbConnection, userid, locid, throughSpaceAndTime) {
	var tx = transaction(dbConnection);
	
	var battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE",
		[userid]).rows[0];
	var isInFight = !!battle;
	
	if (throughSpaceAndTime)
	{
		if (isInFight)
		{
			exports._leaveBattle(tx, battle.id, userid, 'user');
		}
		
		tx.query.sync(tx, 'UPDATE uniusers SET location = $1 WHERE id = $2', [locid, userid]);
		tx.commit();
		return;
	}
	
	var canGo = exports.isTherePathForUserToLocation.sync(null, dbConnection, userid, locid);
	if (isInFight || !canGo)
	{
		tx.rollback();
		return;
	}
	
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
		
		exports._createBattleBetween(tx, locid, pouncedMonsters, [user]);
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
				'SELECT count(*) FROM battle_participants '+ //prevents starting battle with busy monster
				"WHERE kind='monster' AND id = monsters.id) = 0 "+
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
	
	exports._createBattleBetween(tx, user.location, monsters, [user]);
	
	tx.commit.sync(tx);
}.async();


// Escapes user from battle.
exports.goEscape = function(dbConnection, userid) {
	var tx = transaction(dbConnection);
	
	var battle = tx.query.sync(tx,
		"SELECT battle AS id FROM battle_participants WHERE id = $1 AND kind = 'user' FOR UPDATE",
		[userid]).rows[0];
	
	if (!!battle)
	{
		exports._leaveBattle(tx, battle.id, userid, 'user');
	}
	
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


exports._lockAndGetStatsForBattle = function(tx, id, kind) {
	switch(kind)
	{
	case 'user':
		return tx.query.sync(tx,
			"SELECT bp.battle, bp.side, uniusers.power "+
			"FROM uniusers, battles, battle_participants AS bp "+
			"WHERE uniusers.id = $1 "+
				"AND bp.id = $1 "+
				"AND bp.kind = 'user' "+
				"AND battles.id = bp.battle "+
			"", //FOR UPDATE
			[id]).rows[0];
	case 'monster':
		return tx.query.sync(tx,
			"SELECT bp.battle, bp.side, monster_prototypes.power "+
			"FROM monsters, battles, battle_participants AS bp, monster_prototypes "+
			"WHERE monsters.id = $1 "+
				"AND bp.id = $1 "+
				"AND bp.kind = 'monster' "+
				"AND battles.id = bp.battle "+
				"AND monster_prototypes.id = monsters.prototype "+
			"", //FOR UPDATE
			[id]).rows[0];
	}
};

exports._hitAndGetHealth = function(tx, victimId, victimKind, hunterPower) {
	switch(victimKind)
	{
	case 'user':
		return tx.query.sync(tx,
			"UPDATE uniusers "+
			"SET health = health - GREATEST(0, $1-defense)/2 * (0.8+RANDOM()*0.4) "+
			"WHERE id = $2 "+
			"RETURNING health",
			[hunterPower, victimId]).rows[0].health;
	case 'monster':
		return tx.query.sync(tx,
			"UPDATE monsters "+
			"SET health = health - GREATEST(0, $1-protos.defense)/2 * (0.8+RANDOM()*0.4) "+
			"FROM monster_prototypes AS protos "+
			"WHERE monsters.id = $2 "+
				"AND protos.id = monsters.prototype "+
			"RETURNING monsters.health",
			[hunterPower, victimId]).rows[0].health;
	}
};

exports._handleDeathInBattle = function(tx, id, kind) {
	switch(kind)
	{
	case 'monster':
		tx.query.sync(tx,
			"DELETE FROM monsters WHERE id = $1", [id]);
		break;
	case 'user':
		tx.query.sync(tx,
			"UPDATE uniusers "+
			"SET health = health_max, "+
			"    location = (SELECT id FROM locations WHERE initial = 1) "+
			"WHERE id = $1", 
			[id]);
		break;
	}
};

exports._hit = function(dbConnection, hunterId, hunterKind, victimId, victimKind) {
	var tx = transaction(dbConnection);
	
	var hunter = exports._lockAndGetStatsForBattle(tx, hunterId, hunterKind);
	
	if (hunter === undefined)
	{
		tx.rollback.sync(tx);
		return {state: 'canceled', reason: 'hunter not found'};
	}
	
	
	var victim = exports._lockAndGetStatsForBattle(tx, victimId, victimKind);
	
	if (victim === undefined)
	{
		tx.rollback.sync(tx);
		return {state: 'canceled', reason: 'victim not found'};
	}
	
	if (victim.battle !== hunter.battle)
	{
		tx.rollback.sync(tx);
		return {state: 'canceled', reason: 'different battles'};
	}
	
	if (victim.side === hunter.side)
	{
		tx.rollback.sync(tx);
		return {state: 'canceled', reason: "can't hit teammate"};
	}
	
	
	var health = exports._hitAndGetHealth(dbConnection, victimId, victimKind, hunter.power);
	var victimKilled = health <= 0;
	var battleEnded = false;
	
	if (victimKilled)
	{
		battleEnded = exports._leaveBattle(tx, hunter.battle, victimId, victimKind);
		exports._handleDeathInBattle(tx, victimId, victimKind);
	}
	
	tx.commit.sync(tx);
	return {state: 'ok', victimKilled: victimKilled, battleEnded: battleEnded};
};


// Deals damage to opponent in user's battle.
// Opponent is determined by his 'id' and 'kind' among all participants of user's battle.
exports.hitOpponent = function(dbConnection, userid, participantId, participantKind) {
	var result = exports._hit(dbConnection, userid, 'user', participantId, participantKind);
	
	if (result.state !== 'ok' || result.battleEnded)
	{
		return;
	}
	
	var opponents = dbConnection.query.sync(dbConnection,
		"SELECT opponents.id, opponents.kind "+
		"FROM battle_participants AS opponents, "+
			"(SELECT battle, side FROM battle_participants"+
			" WHERE id = $1 AND kind = 'user') AS users "+
		"WHERE opponents.battle = users.battle "+
			"AND opponents.side != users.side",
		[userid]).rows;
	
	for (var i=0; i<opponents.length; i++)
	{
		var opponent = opponents[i];
		result = exports._hit(dbConnection, opponent.id, opponent.kind, userid, 'user');
		
		if (result.battleEnded)
		{
			return;
		}
	}
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


