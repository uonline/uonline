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

exports.getDefaultLocation = function(dbConnection, callback, table) {
	if (!table) table = "locations";
	dbConnection.query(
		'SELECT id FROM '+table+' WHERE `default`=1',
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			} else {
				console.log("before call")
				//{ rows: [ { id: 172926385 } ], rowCount: 1, lastInsertId: undefined }
				callback(undefined, rows[0].id);
				console.log("after call")
			}
		}
	);
}
