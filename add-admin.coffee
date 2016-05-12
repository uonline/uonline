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


{async, await} = require 'asyncawait'
Promise = require 'bluebird'

readline = require 'readline'
rl = readline.createInterface
	input: process.stdin
	output: process.stdout

lib = require './lib.coffee'

u = null
p = null

ask = (what, checker, rules) ->

	_ask = (what, checker, rules, callback) ->
		rl.question "#{what} (#{rules}): ", (answer) ->
			if checker(answer) is true
				callback answer
			else
				_ask(what, checker, rules, callback)

	return new Promise (resolve, reject) ->
		_ask what, checker, rules, resolve


(async ->
	if process.argv[2] is '-h' or process.argv[2] is '--help'
		console.log 'Usage: no params, or <username>, or <username> <password>'
		console.log 'You will be prompted to enter missing params from tty.'
		process.exit 2

	if process.argv.length is 4
		u = process.argv[2]
		p = process.argv[3]
	else if process.argv.length is 3
		u = process.argv[2]
		p = await ask 'Password', lib.validation.passwordIsValid, '4-32 symbols, [!@#$%^&*()_+A-Za-z0-9]'
	else if process.argv.length is 2
		u = await ask 'Username', lib.validation.usernameIsValid, '2-32 symbols, [a-zA-Z0-9а-яА-ЯёЁйЙру _-]'
		p = await ask 'Password', lib.validation.passwordIsValid, '4-32 symbols, [!@#$%^&*()_+A-Za-z0-9]'
	else
		console.log 'Usage: no params, or <username>, or <username> <password>'
		console.log 'You will be prompted to enter missing params from tty.'
		process.exit 2

	config = require './config.coffee'
	anyDB = require 'any-db'
	conn = Promise.promisifyAll(anyDB.createConnection(config.DATABASE_URL))

	exists = await lib.user.userExists conn, u
	if exists is true
		console.log "User `#{u}` already exists."
		process.exit 1

	await lib.user.registerUser conn, u, p, 'admin'

	console.log "New admin `#{u}` registered successfully."
	process.exit 0
)()
