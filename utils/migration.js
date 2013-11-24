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

var FUNC_NAME_COLUMN = 1;
var migrationData = [
	[
		/************** uniusers ****************/
		['uniusers', 'create',
			'id INT AUTO_INCREMENT, PRIMARY KEY (id), '+
			'location INT DEFAULT 1, '+
			'permissions INT DEFAULT 0, '+
			'user TINYTEXT, '+
			'mail TINYTEXT, '+
			'salt TINYTEXT, '+
			'hash TINYTEXT, '+
			'sessid TINYTEXT, '+
			'sessexpire DATETIME, '+
			'reg_time DATETIME, '+

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
			'title TINYTEXT, '+
			'goto TINYTEXT, '+
			'description TEXT, '+
			'area INT, '+
			'picture TINYTEXT, '+
			'default TINYINT(1) DEFAULT 0'],

		/************** areas ****************/
		['areas', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TINYTEXT, '+
			'description TEXT'],

		/************** monster_prototypes ****************/
		['monster_prototypes', 'create', 'id INT AUTO_INCREMENT, PRIMARY KEY (id), '+
			'name TINYTEXT, '+
			'level INT, '+
			'power INT, '+
			'agility INT, '+
			'endurance INT, '+
			'intelligence INT, '+
			'wisdom INT, '+
			'volition INT, '+
			'health_max INT, '+
			'mana_max INT'],
	],
	[
		/************** stats ****************/
		['stats', 'create', 'time TIMESTAMP DEFAULT CURRENT_TIMESTAMP, '+
			'gen_time DOUBLE, '+
			'instance TINYTEXT, '+
			'ip TINYTEXT, '+
			'uagent TINYTEXT, '+
			'url TEXT'],
	],
	[
		/************** monsters ****************/
		['monsters', 'rename', 'id', 'prototype'],
		['monsters', 'rename', 'incarn_id', 'id'],
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
	dbConnection.query("SELECT revision FROM revision", [], function(error, result) {
		if (!!error)
		{
			callback(null, -1);
		}
		else
		{
			callback(null, result.rows[0].revision);
		}
	});
};

exports.setRevision = function(dbConnection, revision, callback) {
	async.series([
			function(callback) {
				dbConnection.query('CREATE TABLE IF NOT EXISTS revision (revision INT NOT NULL)', [], callback);},
			function(callback) {dbConnection.query('DELETE FROM revision', [], callback);},
			function(callback) {dbConnection.query('INSERT INTO revision VALUES (?)', [revision], callback);}
		],
		function(error) {
			callback(error);
		}
	);
};

function justMigrate(dbConnection, revision, callback) {
	var migration = exports.getMigrationsData()[revision];
	var i = 0;
	async.whilst(
		function() {return i < migration.length;},
		function(callback) {
			var params = migration[i++].slice();
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

exports.migrate = function(dbConnection, dest_revision, callback) {
	if (!callback) // if dest_revision is omitted
	{
		callback = dest_revision;
		dest_revision = exports.getNewestRevision();
	}
	else
	{
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
					justMigrate(dbConnection, i++, veryInnerCallback);
				},
				innerCallback
			);
		},
		function(innerCallback) {
			exports.setRevision(dbConnection, dest_revision, callback);
		},
	], callback);
};

