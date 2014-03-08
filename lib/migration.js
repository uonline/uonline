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

var tables = require('./tables.js');

var TABLE_NAME_COLUMN = 0;
var FUNC_NAME_COLUMN = 1;
var migrationData = [
	[
		/************** uniusers ****************/
		['uniusers', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'location INT DEFAULT 1, '+
			'permissions INT DEFAULT 0, '+
			'"user" TEXT, '+ // quotes for pg, see also #312
			'mail TEXT, '+
			'salt TEXT, '+
			'hash TEXT, '+
			'sessid TEXT, '+
			'sessexpire TIMESTAMPTZ, '+
			'reg_time TIMESTAMPTZ, '+

			'fight_mode INT DEFAULT 0, '+
			'autoinvolved_fm INT DEFAULT 0, '+
			'level INT DEFAULT 1, '+
			'health INT DEFAULT 200, '+
			'health_max INT DEFAULT 200, '+
			'mana INT DEFAULT 100, '+
			'mana_max INT DEFAULT 100, '+
			'energy INT DEFAULT 50, '+
			'power INT DEFAULT 3, '+
			'defense INT DEFAULT 3, '+
			'agility INT DEFAULT 3, '+ //ловкость
			'accuracy INT DEFAULT 3, '+ //точность
			'intelligence INT DEFAULT 5, '+ //интеллект
			'initiative INT DEFAULT 5, '+ //инициатива
			'exp INT DEFAULT 0, '+
			'effects TEXT'],

		/************** locations ****************/
		['locations', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'goto TEXT, '+
			'description TEXT, '+
			'area INT, '+
			'picture TEXT, '+
			'"default" SMALLINT DEFAULT 0'],

		/************** areas ****************/
		['areas', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'description TEXT'],

		/************** monster_prototypes ****************/
		['monster_prototypes', 'create', 'id SERIAL, PRIMARY KEY (id), '+
			'name TEXT, '+
			'level INT, '+
			'power INT, '+
			'agility INT, '+
			'endurance INT, '+
			'intelligence INT, '+
			'wisdom INT, '+
			'volition INT, '+
			'health_max INT, '+
			'mana_max INT'],

		/************** monsters ****************/
		['monsters', 'create', 'incarn_id SERIAL, PRIMARY KEY (incarn_id), '+
			'id INT, '+
			'location INT, '+
			'health INT, '+
			'mana INT, '+
			'effects TEXT, '+
			'attack_chance INT'],
	],
	[
		/************** monsters ****************/
		['monsters', 'renameCol', 'id', 'prototype'],
		['monsters', 'renameCol', 'incarn_id', 'id'],
	],
	[
		/************** uniusers ****************/
		['uniusers', 'renameCol', 'sessexpire', 'sess_time'],
	],
];

exports.getMigrationsData = function() {
	return migrationData;
};

//for testing
exports.setMigrationsData = function(data) {
	migrationData = data;
};

exports.getNewestRevision = function() {
	return exports.getMigrationsData().length-1;
};

exports.getCurrentRevision = function(dbConnection, callback) {
	try
	{
		dbConnection.query("SELECT revision FROM revision", [], function (error, result) {
			if (!!error)
			{
				if (error.code === 'ER_NO_SUCH_TABLE' || error.code === '42P01') // MySQL, PostreSQL
				{
					callback(null, -1);
				}
				else
				{
					callback(error, null);
				}
			}
			else
			{
				callback(null, result.rows[0].revision);
			}
		});
	}
	catch (ex)
	{
		callback(ex, null);
	}
};

exports.setRevision = function(dbConnection, revision, callback) {
	async.series([
			function(callback) {
				dbConnection.query('CREATE TABLE IF NOT EXISTS revision (revision INT NOT NULL)', [], callback);},
			function(callback) {dbConnection.query('DELETE FROM revision', [], callback);},
			function(callback) {dbConnection.query('INSERT INTO revision VALUES ($1)', [revision], callback);}
		],
		function(error) {
			callback(error);
		}
	);
};

function justMigrate(dbConnection, revision, table, callback) {
	if (arguments.length == 3)
	{
		callback = table;
		table = undefined;
	}
	var migration = exports.getMigrationsData()[revision];
	var i = 0;
	async.whilst(
		function() {return i < migration.length;},
		function(callback) {
			var params = migration[i++].slice();
			//mb convert for_tables to hashmap?
			if (table && table!=params[TABLE_NAME_COLUMN])
			{
				callback(null, null);
				return;
			}
			var funcName = params.splice(FUNC_NAME_COLUMN, 1);
			var func = tables[funcName];
			params.unshift(dbConnection);
			params.push(callback);
			func.apply(tables, params);
		},
		callback
	);
}

exports.migrateOne = function(dbConnection, revision, callback) {
	async.waterfall([
		function(innerCallback) {
			exports.getCurrentRevision(dbConnection, innerCallback);
		},
		function(curRevision, innerCallback) {
			if (curRevision == revision)
			{
				callback(null);
				return;
			}
			if (curRevision != revision-1)
			{
				callback("Can't migrate to revision <"+revision+"> from current <"+curRevision+">");
				return;
			}
			justMigrate(dbConnection, revision, innerCallback);
		},
		function(innerCallback) {
			exports.setRevision(dbConnection, revision, callback);
		},
	], callback);
};

exports.migrate = function(dbConnection, dest_revision, table, callback) {
	switch (arguments.length)
	{
	case 2:
		callback = dest_revision;
		dest_revision = exports.getNewestRevision();
		break;
	case 3:
		callback = table;
		table = undefined;
		/* jshint -W086 */
	default: //no break here!
		/* jshint +W086 */
		dest_revision = Math.min(dest_revision, exports.getNewestRevision());
	}
	async.waterfall([
		function(innerCallback) {
			exports.getCurrentRevision(dbConnection, innerCallback);
		},
		function(current, innerCallback) {
			var i = current+1;
			async.whilst(
				function() {return i<=dest_revision;},
				function(veryInnerCallback) {
					justMigrate(dbConnection, i++, table, veryInnerCallback);
				},
				innerCallback
			);
		},
		function(innerCallback) {
			if (table)
			{
				innerCallback();
			}
			else
			{
				exports.setRevision(dbConnection, dest_revision, innerCallback);
			}
		},
	], callback);
};

