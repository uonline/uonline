#!/usr/bin/env node
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


'use strict';

var async = require('async');
var config = require('./config.js');
var utils = require('./utils.js');

var dashdash = require('dashdash');
var options = [
	{
		names: ['help', 'h'],
		type: 'bool',
		help: 'Print this help and exit.'
	},
	{
		names: ['info', 'i'],
		type: 'bool',
		help: 'Show current revision and status.'
	},
	{
		names: ['create-database', 'C'],
		type: 'string',
		help: 'Create "test" or "main" database. Or "both".'
	},
	{
		names: ['drop-database', 'D'],
		type: 'string',
		help: 'Drop "test" or "main" database. Or "both".'
	},
	{
		names: ['migrate-tables', 'm'],
		type: 'bool',
		help: 'Migrate to latest revision.'
	},
];

var parser = dashdash.createParser({options: options});

try
{
	var opts = parser.parse(process.argv);
}
catch (exception)
{
	console.error('error: ' + exception.message);
	process.exit(1);
}

if (opts._args.length > 0)
{
	console.error('error: unexpected argument "%s"', opts._args[0]);
	process.exit(1);
}

if (opts._order.length === 0)
{
	opts.help = true;
}

function checkError(error, dontExit)
{
	if (!!error)
	{
		console.log(error);
		if (!dontExit) process.exit(1);
	}
}

//console.log("# opts:", opts); // debug

/*
var optimist = require('optimist');
var argv = optimist
	.alias('help', 'h')
	.alias('info', 'i')
	.alias('tables', 't')
	.alias('unify-validate', 'l')
	.alias('unify-export', 'u')
	.alias('optimize', 'o')
	.alias('optimize', 'O')
	.alias('test-monsters', 'm')
	.alias('drop', 'd')
	.usage('Usage: $0 <commands>')
	.describe('help', 'Show this text')
	.describe('info', 'Show current revision and status')
	.describe('tables', 'Migrate tables to the last revision')
	.describe('unify-validate', 'Validate unify files')
	.describe('unify-export', 'Parse unify files and push them to database')
	.describe('optimize', 'Optimize tables')
	.describe('test-monsters', 'Insert test monsters')
	.describe('drop', 'Drop all tables and set revision to -1')
	.boolean(['help','info','tables','unify-validate','unify-export','optimize','test-monsters','drop'])
	.argv;

// [--database] [--tables] [--unify-validate] [--unify-export] [--optimize] [--test-monsters] [--drop]

if (argv.help === true)
{
	optimist.showHelp();
}
*/

if (opts.help === true)
{
	var help = parser.help({includeEnv: true}).trimRight();
	console.log("\nUsage: node init.js <commands>\n\n" + help);
	process.exit(2);
}

var anyDB = require('any-db');

if (opts.info === true)
{
	var mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL);
	utils.migration.getCurrentRevision(mysqlConnection, function (error, result) {
		if (!!error)
		{
			console.log(error);
			process.exit(1);
		}
		else
		{
			var newest = utils.migration.getNewestRevision();
			console.log('init.js with ' + (newest+1) + ' revisions on board.');
			console.log('Current revision is ' + result + ' (' +
				(result < newest ? 'needs update':'up to date') +
				').');
			process.exit(0);
		}
	});
}

if (opts.create_database !== undefined)
{
	var func_count = 0;
	var create = function(db_url) {
		func_count++;
		var db_path = db_url.match(/.+\//)[0];
		var db_name = db_url.match(/[^\/]+$/)[0];
		var conn = anyDB.createConnection(db_path);
		conn.query('CREATE DATABASE '+db_name, [], function(error, result) {
			func_count--;
			checkError(error, func_count !== 0);
			console.log(db_name+' created.');
			if (func_count === 0) process.exit(0);
		});
	};
	
	if (opts.create_database === "main" || opts.create_database === "both")
	{
		create(config.MYSQL_DATABASE_URL);
	}
	if (opts.create_database === "test" || opts.create_database === "both")
	{
		create(config.MYSQL_DATABASE_URL_TEST);
	}
}

if (opts.drop_database !== undefined)
{
	var func_count = 0;
	var drop = function(db_url) {
		func_count++;
		var db_path = db_url.match(/.+\//)[0];
		var db_name = db_url.match(/[^\/]+$/)[0];
		var conn = anyDB.createConnection(db_path);
		conn.query('DROP DATABASE '+db_name, [], function(error, result) {
			func_count--;
			checkError(error, func_count !== 0);
			console.log(db_name+' dropped.');
			if (func_count === 0) process.exit(0);
		});
	};
	
	if (opts.drop_database === "main" || opts.drop_database === "both")
	{
		drop(config.MYSQL_DATABASE_URL);
	}
	if (opts.drop_database === "test" || opts.drop_database === "both")
	{
		drop(config.MYSQL_DATABASE_URL_TEST);
	}
}

if (opts.migrate_tables === true)
{
	var mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL);
	utils.migration.migrate(mysqlConnection, function(error) {
		checkError(error);
		process.exit(0);
	});
}




