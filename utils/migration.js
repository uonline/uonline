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
		['uniusers', 'create', 'id INT AUTO_INCREMENT, PRIMARY KEY (id)'],
		['uniusers', 'addCol', 'location INT DEFAULT 1'],
		['uniusers', 'addCol', 'permissions INT DEFAULT 0'],
		['uniusers', 'addCol', 'user TINYTEXT'],
		['uniusers', 'addCol', 'mail TINYTEXT'],
		['uniusers', 'addCol', 'salt TINYTEXT'],
		['uniusers', 'addCol', 'hash TINYTEXT'],
		['uniusers', 'addCol', 'sessid TINYTEXT'],
		['uniusers', 'addCol', 'sessexpire DATETIME'],
		['uniusers', 'addCol', 'reg_time DATETIME'],

		['uniusers', 'addCol', 'fight_mode INT DEFAULT 0'],
		['uniusers', 'addCol', 'autoinvolved_fm INT DEFAULT 0'],
		['uniusers', 'addCol', 'level INT DEFAULT 1'],
		['uniusers', 'addCol', 'health INT DEFAULT 200'],
		['uniusers', 'addCol', 'health_max INT DEFAULT 200'],
		['uniusers', 'addCol', 'mana INT DEFAULT 100'],
		['uniusers', 'addCol', 'mana_max INT DEFAULT 100'],
		['uniusers', 'addCol', 'energy INT DEFAULT 50'],
		['uniusers', 'addCol', 'power INT DEFAULT 3'],
		['uniusers', 'addCol', 'defense INT DEFAULT 3'],
		['uniusers', 'addCol', 'agility INT DEFAULT 3'], //ловкость
		['uniusers', 'addCol', 'accuracy INT DEFAULT 3'], //точность
		['uniusers', 'addCol', 'intelligence INT DEFAULT 5'], //интеллект
		['uniusers', 'addCol', 'initiative INT DEFAULT 5'], //инициатива
		['uniusers', 'addCol', 'exp INT DEFAULT 0'],
		['uniusers', 'addCol', 'effects TEXT'],

		/************** locations ****************/
		['locations', 'create', 'id INT, PRIMARY KEY (id)'],
		['locations', 'addCol', 'title TINYTEXT'],
		['locations', 'addCol', 'goto TINYTEXT'],
		['locations', 'addCol', 'description TEXT'],
		['locations', 'addCol', 'area INT'],
		['locations', 'addCol', 'picture TINYTEXT'],
		['locations', 'addCol', 'default TINYINT(1) DEFAULT 0'],

		/************** areas ****************/
		['areas', 'create', 'id INT, PRIMARY KEY (id)'],
		['areas', 'addCol', 'title TINYTEXT'],
		['areas', 'addCol', 'description TEXT'],

		/************** monster_prototypes ****************/
		['monster_prototypes', 'create', 'id INT AUTO_INCREMENT, PRIMARY KEY (id)'],
		['monster_prototypes', 'addCol', 'name TINYTEXT'],
		['monster_prototypes', 'addCol', 'level INT'],
		['monster_prototypes', 'addCol', 'power INT'],
		['monster_prototypes', 'addCol', 'agility INT'],
		['monster_prototypes', 'addCol', 'endurance INT'],
		['monster_prototypes', 'addCol', 'intelligence INT'],
		['monster_prototypes', 'addCol', 'wisdom INT'],
		['monster_prototypes', 'addCol', 'volition INT'],
		['monster_prototypes', 'addCol', 'health_max INT'],
		['monster_prototypes', 'addCol', 'mana_max INT'],
	],
	[
		/************** stats ****************/
		['stats', 'create', 'time TIMESTAMP DEFAULT CURRENT_TIMESTAMP'],
		['stats', 'addCol', 'gen_time DOUBLE'],
		['stats', 'addCol', 'instance TINYTEXT'],
		['stats', 'addCol', 'ip TINYTEXT'],
		['stats', 'addCol', 'uagent TINYTEXT'],
		['stats', 'addCol', 'url TEXT'],
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

exports.getCurrentRevision = function() {
	return 0;
};

exports.setRevision = function() {
	
};

exports.migrate = function(dbConnection, migration_id, callback) {
	var migration = exports.getMigrationsData()[migration_id];
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
};

exports.migrateAll = function(dbConnection, callback) {
	var current = exports.getCurrentRevision();
	var last = exports.getNewestRevision();
	var i = current;
	async.whilst(
		function() {return i<=last;},
		function(callback) {
			exports.migrate(dbConnection, i++, callback);
		},
		callback
	);
};

