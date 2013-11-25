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
var mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL);

if (opts.info === true)
{
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
