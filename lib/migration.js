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
var sync = require('sync');

var tables = require('./tables.js');

var TABLE_NAME_COLUMN = 0;
var FUNC_NAME_COLUMN = 1;
var migrationData = [
	[
		// create uniusers
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
			'health_max INT DEFAULT 200, '+//
			'mana INT DEFAULT 100, '+
			'mana_max INT DEFAULT 100, '+//
			'energy INT DEFAULT 50, '+//
			'power INT DEFAULT 3, '+//
			'defense INT DEFAULT 3, '+//
			'agility INT DEFAULT 3, '+ //ловкость//
			'accuracy INT DEFAULT 3, '+ //точность//
			'intelligence INT DEFAULT 5, '+ //интеллект//
			'initiative INT DEFAULT 5, '+ //инициатива//
			'exp INT DEFAULT 0, '+
			'effects TEXT'],

		// create locations
		['locations', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'goto TEXT, '+
			'description TEXT, '+
			'area INT, '+
			'picture TEXT, '+
			'"default" SMALLINT DEFAULT 0'],

		// create areas
		['areas', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'description TEXT'],

		// create monster_prototypes
		['monster_prototypes', 'create', 'id SERIAL, PRIMARY KEY (id), '+
			'name TEXT, '+
			'level INT, '+
			'power INT, '+
			'agility INT, '+
			'endurance INT, '+ // --> defense
			'intelligence INT, '+
			'wisdom INT, '+ // --> accuracy
			'volition INT, '+ // --> initiative_min
			'health_max INT, '+
			'mana_max INT'],// + energy

		// create monsters
		['monsters', 'create', 'incarn_id SERIAL, PRIMARY KEY (incarn_id), '+
			'id INT, '+
			'location INT, '+
			'health INT, '+
			'mana INT, '+
			'effects TEXT, '+
			'attack_chance INT'],
	],
	[
		// make columns sane in monsters
		['monsters', 'renameCol', 'id', 'prototype'],
		['monsters', 'renameCol', 'incarn_id', 'id'],
	],
	[
		// now we store last action time instead of session expiration time
		['uniusers', 'renameCol', 'sessexpire', 'sess_time'],
	],
	[
		// user -> username
		['uniusers', 'renameCol', '"user"', 'username'],
	],
	[
		// index for sessid, otherwise it's too slow
		['uniusers', 'createIndex', 'sessid'],
	],
	[
		// new system
		['monster_prototypes', 'addCol', 'energy INT'],
		['monster_prototypes', 'renameCol', 'endurance', 'defense'],
		['monster_prototypes', 'renameCol', 'wisdom', 'accuracy'],
		['monster_prototypes', 'renameCol', 'volition', 'initiative_min'],
		['monster_prototypes', 'addCol', 'initiative_max INT'],
	],
	[
		// goto -> ways
		['locations', 'renameCol', 'goto', 'ways'],
	],
	[
		// current initiative for monsters
		['monsters', 'addCol', 'initiative INT'],
	],
	[
		// #410
		['locations', 'renameCol', '"default"', 'initial'],
	],
	[
		['battles', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'location INT, '+
			'turn_number INT DEFAULT 0, '+
			'is_over INT DEFAULT 0'],
		['battle_participants', 'create',
			'battle INT, '+
			'id INT, '+
			'kind TEXT, '+
			'index INT, '+
			'side INT'],
		//['uniusers', 'addCol', 'battle INT'],
	],
	[
		['creature_kind', 'createEnum', "'user', 'monster'"],
		// error: column "kind" cannot be cast to type creature_kind
		//['battle_participants', 'changeCol', 'kind', 'creature_kind'],
		['battle_participants', 'dropCol', 'kind'],
		['battle_participants', 'addCol', 'kind creature_kind'],
	]
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

function justMigrate(dbConnection, revision, for_tables) {
	var migration = exports.getMigrationsData()[revision];
	
	for (var i=0; i<migration.length; i++)
	{
		var params = migration[i].slice();
		//mb convert for_tables to hashmap?
		if (for_tables && for_tables.indexOf(params[TABLE_NAME_COLUMN])===-1)
		{
			continue;
		}
		var funcName = params.splice(FUNC_NAME_COLUMN, 1);
		var func = tables[funcName];
		params.unshift(dbConnection);
		params.unshift(null);
		func.sync.apply(func, params);
	}
}

exports.migrateOne = function(dbConnection, revision) {
	var curRevision = exports.getCurrentRevision.sync(null, dbConnection);
	
	if (curRevision == revision)
	{
		return;
	}
	if (curRevision != revision-1)
	{
		throw new Error("Can't migrate to revision <"+revision+"> from current <"+curRevision+">");
	}
	justMigrate(dbConnection, revision);
	
	exports.setRevision.sync(null, dbConnection, revision);
}.async();

exports.migrate = function(dbConnection, opts) {
	opts = opts || {};
	
	if (opts.dest_revision === undefined)
	{
		opts.dest_revision = Infinity;
	}
	opts.dest_revision = Math.min(opts.dest_revision, exports.getNewestRevision());
	
	var for_tables = opts.tables || (opts.table ? [opts.table] : undefined);
	
	var curRevision = exports.getCurrentRevision.sync(null, dbConnection);
	for (var i=curRevision+1; i<=opts.dest_revision; i++)
	{
		
		if (opts.verbose)
		{
			console.log('Migrating '+(for_tables ? '<'+for_tables+'> ' : '')+'to revision '+i);
		}
		justMigrate(dbConnection, i, for_tables);
	}
	
	if (!for_tables)
	{
		exports.setRevision.sync(null, dbConnection, opts.dest_revision);
	}
	
	if (opts.verbose)
	{
		console.log('Migrated.');
	}
}.async();

