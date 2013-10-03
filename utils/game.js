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
			if (result.rowCount == 0) error = "Wrong user's sessid";
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
			if (result.rowCount == 0) error = "No matches found";
			if (!!error) return callback(error, null);
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
			if (!!error) return callback(error, null);
			var a = result.rows[0].goto.split("|");
			for (var i=0;i<a.length;i++) {
				var s = a[i].split("=");
				a[i] = {to: s[1], name: s[0]};
			}
			callback(null, a);
		}
	);
};*/

/*exports.changeLocation = function(dbConnection, sessid, locid, callback) {
	var count = 0;
	function onend(error, result) {
		if (!!error) return callback(error, undefined);
		callback(undefined, result.rows[0]);
	}
	dbConnection.query(
		'START TRANSACTION;'+
		'  SELECT 1;'+
		'COMMIT;',
		function(error, result) {
			console.log(error, result)
		});
}*/


