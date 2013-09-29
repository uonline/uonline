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
			if (!!error) {
				callback(error, undefined);
			} else {
				//{ rows: [ { id: 172926385 } ], rowCount: 1, lastInsertId: undefined }
				callback(undefined, result.rows[0].id);
			}
		}
	);
};

exports.getUserLocationId = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT location FROM uniusers WHERE sessid = ?',
		[sessid],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			} else {
				callback(undefined, result.rows[0].location);
			}
		}
	);
};

/*exports.getUserLocationId = function(dbConnection, sessid, callback) {
	dbConnection.query(
		'SELECT locations.area FROM locations, uniusers WHERE uniusers.sessid=? AND locations.id=uniusers.location',
		[sessid],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			} else {
				console.log(result.rows[0])
				callback(undefined, result.rows[0]);
			}
		}
	);
};*/

