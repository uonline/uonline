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

exports.getDefaultLocation = function(dbConnection, callback) {
	dbConnection.query(
		'SELECT * FROM locations WHERE `default` = 1',
		function (error, result) {
			callback(error, error || result.rows[0]);
		}
	);
};

exports.getUserLocationId = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT location FROM uniusers WHERE sessid = ?',
		[sessid],
		function (error, result) {
			if (result.rowCount === 0) error = "Wrong user's sessid";
			callback(error, error || result.rows[0].location);
		}
	);
};

exports.getUserLocation = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT locations.* FROM locations, uniusers '+
		'WHERE uniusers.sessid=? AND locations.id = uniusers.location',
		[sessid],
		function (error, result) {
			if (result.rowCount === 0) error = "No matches found";
			if (!!error) {callback(error, null); return;}
			var res = result.rows[0];
			var goto = res.goto.split("|");
			for (var i=0;i<goto.length;i++) {
				var s = goto[i].split("=");
				goto[i] = {id: s[1], text: s[0]};
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

exports.changeLocation = function(dbConnection, sessid, locid, callback) {
	//var c = function(e,r) {console.log(e,r)}
	exports.getUserLocation(dbConnection, sessid, function(error, result) {
		
		if (!!error) {callback(error, null); return;}
		
		var i = result.goto.length-1;
		for (;i>=0; i--)
			if (result.goto[i].id == locid)
				break;
		if (i < 0) {callback('No way from location '+result.id+' to '+locid, null); return;}
		
		var tx = dbConnection.begin();
		tx.on('error', callback);
		tx.query('UPDATE uniusers SET location = ? WHERE sessid = ?', [locid, sessid]);
		tx.query(
			'UPDATE uniusers, locations, monsters '+
			'SET uniusers.autoinvolved_fm = 1, uniusers.fight_mode = 1 '+
			'WHERE uniusers.sessid = ? '+
				'AND uniusers.location = monsters.location '+
				'AND RAND()*100 <= monsters.attack_chance', [sessid]);
		tx.commit(callback);
	});
};

