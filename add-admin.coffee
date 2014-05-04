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
sync = require 'sync'

readline = require 'readline'
rl = readline.createInterface
	input: process.stdin
	output: process.stdout

u = null
p = null

ask = (what, checker, rules, callback) ->
	rl.question "#{what} (#{rules}): ", (answer) ->
		if checker(answer) is true
			callback null, answer
		else
			ask(what, checker, rules, callback)

sync ->
	if process.argv.length is 4
		u = process.argv[2]
		p = process.argv[3]
	else
		u = ask.sync null, 'Username', lib.validation.usernameIsValid, '2-32 symbols, [a-zA-Z0-9а-яА-ЯёЁйЙру _-]'
		p = ask.sync null, 'Password', lib.validation.passwordIsValid, '4-32 symbols, [!@#$%^&*()_+A-Za-z0-9]'

	config = require './config.js'
	anyDB = require 'any-db'
	conn = anyDB.createConnection config.DATABASE_URL

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
