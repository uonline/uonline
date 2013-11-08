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

exports.tableExists = function(dbConnection, name, callback)
{
	dbConnection.query(
		"SELECT count(*) AS result FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?",
		[dbConnection.config.database, name],
		function (error, result){
			callback(error, error || (result.rows[0].result > 0));
		}
	);
};

exports.create = function(dbConnection, table, data, callback) {
	dbConnection.query(
		'CREATE TABLE '+table+' ('+data+')',
		[],
		function (error, result) {
			callback(error, error || true);
		}
	);
};

exports.addCol = function(dbConnection, table, column, callback) {
	dbConnection.query(
		'ALTER TABLE '+table+' ADD COLUMN '+column,
		[],
		function (error, result) {
			callback(error, error || true);
		}
	);
};

exports.renameCol = function(dbConnection, table, colOld, colNew, callback) {
	dbConnection.query(
		'SELECT COLUMN_TYPE FROM information_schema.COLUMNS '+
		'WHERE TABLE_NAME = ? '+
		'AND COLUMN_NAME = ?', [table, colOld],
		function(error, result) {
			if (error)
			{
				callback(error, null);
				return;
			}
			if (result.rowCount === 0)
			{
				callback("No such table/column", null);
				return;
			}
			dbConnection.query(
				'ALTER TABLE '+table+' CHANGE COLUMN '+colOld+' '+colNew+' '+result.rows[0].COLUMN_TYPE,
				[],
				function (error, result) { callback(error, error || true); }
			);
		}
	);
};

exports.dropCol = function(dbConnection, table, column, callback) {
	dbConnection.query(
		'ALTER TABLE '+table+' DROP COLUMN '+column,
		[],
		function (error, result) {
			callback(error, error || true);
		}
	);
};

