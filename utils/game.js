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
		'SELECT id FROM locations WHERE `default`=1',
		function (error, result) {
			callback(error, error || result.rows[0].id);
		}
	);
};

exports.getUserLocationId = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT location FROM uniusers WHERE sessid = ?',
		[sessid],
		function (error, result) {
			callback(error, error || result.rows[0].location);
		}
	);
};

exports.getUserAreaId = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT locations.area FROM locations, uniusers '+
		'WHERE uniusers.sessid=? AND locations.id = uniusers.location',
		[sessid],
		function (error, result) {
			callback(error, error || result.rows[0].area);
		}
	);
};

exports.getCurrentLocationTitle = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT locations.title FROM locations, uniusers '+
		'WHERE uniusers.sessid = ? AND locations.id = uniusers.location',
		[sessid],
		function (error, result) {
			callback(error, error || result.rows[0].title);
		}
	);
};

exports.getCurrentLocationDescription = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT description FROM locations, uniusers '+
		'WHERE uniusers.sessid = ? AND locations.id = uniusers.location',
		[sessid],
		function (error, result) {
			callback(error, result.rows[0].description);
		}
	);
};

exports.getAllowedZones = function(dbConnection, sessid, ids_only, callback) {
	if (!callback) callback = ids_only;
	dbConnection.query(
		'SELECT locations.goto FROM locations, uniusers '+
		'WHERE uniusers.sessid = ? AND locations.id = uniusers.location AND uniusers.fight_mode = 0',
		[sessid],
		function (error, result) {
			if (!!error) return callback(error, undefined);
			var a = result.rows[0].goto.split("|");
			for (var i=0;i<a.length;i++)
				a[i] = ids_only ?
					a[i].substr(0,a[i].indexOf("=")) :
					a[i].split("=");
			callback(undefined, a);
		}
	);
};

/*exports.changeLocation = function(dbConnection, sessid, locid, callback) {
	var count = 0;
	function onend(error, result) {
		if (!!error) return callback(error, undefined);
		callback(undefined, result.rows[0]);
	}
	dbConnection.query(
		'UPDATE uniusers SET location = ? WHERE sessid = ?',
		[locid, sessid], onend);
	dbConnection.query(
		'SELECT max(attack_chance) FROM monsters, uniusers'+
		'WHERE uniusers.sessid = ? AND uniusers.location = monsters.location',
		[sessid], function(error, result) {

		});
}*/


