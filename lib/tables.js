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

var async = require('async');

exports.tableExists = function(dbConnection, name, callback)
{
	dbConnection.query(
		'SELECT count(*) AS result FROM information_schema.tables WHERE table_name = $1',
		[name],
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

exports.renameCol = function (dbConnection, table, colOld, colNew, callback) {
	// TODO: cleanup, async.auto is not needed anymore
	//ALTER TABLE employee RENAME COLUMN start_date TO hire_date;
	async.auto({
			makeinstall: function (callback, results) {
				dbConnection.query(
					'ALTER TABLE '+table+' RENAME COLUMN '+colOld+' TO '+colNew,
					[], callback
				);
			},
		},
		function (error, results) {
			callback(error, error || true);
		}
	);
};

exports.changeCol = function(dbConnection, table, colName, colAttrs, callback) {
	dbConnection.query(
		'ALTER TABLE '+table+' CHANGE COLUMN '+colName+' '+colName+' '+colAttrs,
		[], callback);
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

