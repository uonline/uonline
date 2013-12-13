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
var math = require('./math.js');

exports.getDefaultLocation = function(dbConnection, callback) {
	dbConnection.query(
		'SELECT * FROM locations WHERE `default` = 1',
		function (error, result) {
			if (!!result && result.rowCount === 0)
			{
				error = 'default location is not defined';
			}
			if (!!result && result.rowCount > 1)
			{
				error = 'there is more than one default location';
			}
			callback(error, error || result.rows[0]);
		}
	);
};

exports.getUserLocationId = function(dbConnection, userid, callback) {
	dbConnection.query(
		'SELECT location FROM uniusers WHERE id = ?',
		[userid],
		function (error, result) {
			if (!!result && result.rowCount === 0)
			{
				error = "Wrong user's id";
			}
			callback(error, error || result.rows[0].location);
		}
	);
};

exports.getUserLocation = function(dbConnection, userid, callback) {
	dbConnection.query(
		'SELECT locations.* FROM locations, uniusers '+
		'WHERE uniusers.id=? AND locations.id = uniusers.location',
		[userid],
		function (error, result) {
			if (!!result && result.rowCount === 0)
			{
				error = "Wrong user's id";
			}
			if (!!error)
			{
				callback(error, null);
				return;
			}
			var res = result.rows[0];
			var goto = res.goto.split("|");
			for (var i=0;i<goto.length;i++)
			{
				var s = goto[i].split("=");
				goto[i] = {id: parseInt(s[1], 10), text: s[0]};
			}
			res.goto = goto;
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

exports.changeLocation = function(dbConnection, userid, locid, callback) {
	//var c = function(e,r) {console.log(e,r)}
	exports.getUserLocation(dbConnection, userid, function(error, result) {

		if (!!error) {callback(error, null); return;}

		var found = false;
		for (var i in result.goto)
		{
			if (result.goto[i].id == locid)
			{
				found = true;
				break;
			}
		}
		if (!found)
		{
			callback('No way from location '+result.id+' to '+locid, null);
			return;
		}

		var tx = dbConnection.begin();
		tx.on('error', callback);
		tx.query('UPDATE uniusers SET location = ? WHERE id = ?', [locid, userid]);
		tx.query(
			'UPDATE uniusers, locations, monsters '+
			'SET uniusers.autoinvolved_fm = 1, uniusers.fight_mode = 1 '+
			'WHERE uniusers.id = ? '+
				'AND uniusers.location = monsters.location '+
				'AND RAND()*100 <= monsters.attack_chance', [userid]);
		tx.commit(callback);
	});
};

exports.goAttack = function(dbConnection, userid, callback) {
	dbConnection.query("UPDATE uniusers SET fight_mode = 1 WHERE id = ?", [userid], callback);
};

exports.goEscape = function(dbConnection, userid, callback) {
	dbConnection.query("UPDATE uniusers SET fight_mode = 0, autoinvolved_fm = 0 WHERE id = ?", [userid], callback);
};

exports.getUsersOnLocation = function(dbConnection, locid, callback) {
	dbConnection.query(
		"SELECT id, user FROM uniusers "+
		"WHERE sessexpire > NOW() AND location = ?",
		[locid],
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
		'WHERE monsters.location = ? '+
		'AND monster_prototypes.id = monsters.prototype',
		[locid],
		function(error, result) {
			callback(error, error || result.rows);
		}
	);
};

exports.uninvolve = function(dbConnection, userid, callback) {
	dbConnection.query("UPDATE uniusers SET autoinvolved_fm = 0 WHERE id = ?", [userid], callback);
};

var characters = [
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
exports.getUserCharacters = function(dbConnection, userid, callback) {
	dbConnection.query(
		"SELECT "+joinedCharacters+" FROM uniusers WHERE id = ?",
		[userid],
		function(error, result) {
			if (!!error)
			{
				callback(error, null);
				return;
			}
			var res = result.rows[0];
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


