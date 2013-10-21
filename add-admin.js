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


"use strict";

var utils = require('./utils.js');

console.log("Warning: PHP and Node.js have different hashing algorithms.\n" +
	utils.prettyprint.spaces(9) + "Don't try to use them together.");

if (process.argv.length !== 4)
{
	console.log('Usage: <username> <password>');
	process.exit(2);
}

var u = process.argv[2];
var p = process.argv[3];

if (!utils.validation.usernameIsValid(u))
{
	console.log('Incorrect username.');
	console.log('Must be: 2-32 symbols, [a-zA-Z0-9а-яА-ЯёЁйЙру _-].');
	process.exit(1);
}

if (!utils.validation.passwordIsValid(p))
{
	console.log('Incorrect password.');
	console.log('Must be: 4-32 symbols, [!@#$%^&*()_+A-Za-z0-9].');
	process.exit(1);
}

var config = require('./config.js');
var async = require('async');
var anyDB = require('any-db');
var conn = anyDB.createConnection(config.MYSQL_DATABASE_URL);

utils.user.userExists(conn, u, function(error, result){
	if (!!error)
	{
		console.log('Error: '+require('util').inspect(error));
		process.exit(1);
	}
	else if (result === true)
	{
		console.log('User `'+u+'` already exists.');
		process.exit(1);
	}
	else
	{
		utils.user.registerUser(conn, u, p, config.PERMISSIONS_ADMIN, function(error, result){
			if (!!error)
			{
				console.log('Error: '+require('util').inspect(error));
				process.exit(1);
			}
			else
			{
				console.log('New admin `'+u+'` registered successfully.');
				process.exit(0);
			}
		});
	}
});
