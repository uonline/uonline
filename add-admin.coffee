#!/usr/bin/env coffee

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


'use strict'


lib = require './lib.coffee'

if process.argv.length != 4
	console.log 'Usage: <username> <password>'
	process.exit 2

u = process.argv[2]
p = process.argv[3]

if !lib.validation.usernameIsValid(u)
	console.log 'Incorrect username.'
	console.log 'Must be: 2-32 symbols, [a-zA-Z0-9а-яА-ЯёЁйЙру _-].'
	process.exit 1

if !lib.validation.passwordIsValid(p)
	console.log 'Incorrect password.'
	console.log 'Must be: 4-32 symbols, [!@#$%^&*()_+A-Za-z0-9].'
	process.exit 1

config = require './config.js'
sync = require 'sync'
anyDB = require 'any-db'
conn = anyDB.createConnection config.DATABASE_URL


sync ->
	try
		exists = lib.user.userExists.sync null, conn, u
		if exists is true
			console.log "User `#{u}` already exists."
			process.exit 1

		lib.user.registerUser.sync null, conn, u, p, config.PERMISSIONS_ADMIN
		console.log "New admin `#{u}` registered successfully."
		process.exit 0
	catch ex
		console.error ex.stack
		process.exit 1
