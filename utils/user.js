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

exports.userExists = function(dbConnection, username, callback, table)
{
	if (!table) table = 'uniusers';
	dbConnection.query(
		// Seems unsafe? It is.
		// But escaper doesn't know that table name and column value are different things.
		'SELECT * FROM `'+table+'` WHERE user = ?',
		[username],
		function (error, result){
			if (!!error)
			{
				callback(error, undefined);
			}
			else
			{
				callback(undefined, (result.rowCount > 0));
			}
		}
	);
};
