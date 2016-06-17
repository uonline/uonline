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


ask = require 'require-r'
{async, await} = require 'asyncawait'
promisifyAll = require("bluebird").promisifyAll
crypto = promisifyAll require 'crypto'
uuid = require 'node-uuid'

config = ask 'config'
Account = ask 'domain/account'
math = ask 'lib/math'


module.exports = class AccountPG extends Account
	constructor: (@db) ->

	existsID: async (id) ->
		(await @db.one("SELECT COUNT(*) FROM account WHERE id = $1", id)).count > 0

	byID: (id) ->
		@db.oneOrNone("SELECT * FROM account WHERE id = $1", id)

	existsName: async (username) ->
		(await @db.one("SELECT COUNT(*)::int FROM account WHERE lower(name) = lower($1)", username)).count > 0

	byName: (username) ->
		@db.oneOrNone("SELECT * FROM account WHERE lower(name) = lower($1)", username)

	# Create a new user with given username, password and permissions (see config.js).
	# Returns a string with sessid, or an error.
	create: async (username, password, permissions) ->
		if await @existsName(username)
			throw new Error 'user already exists'

		salt = math.createSalt 16
		hash = await crypto.pbkdf2Async password, salt, 4096, 256, 'sha512'
		sessid = null

		id = (await @db.one(
			'''
			INSERT INTO account
				(name, password_salt, password_hash, sessid, reg_time, sess_time, permissions, character_id)
			VALUES
				($1, $2, $3, $4, NOW(), NOW(), $5, $6)
			RETURNING id
			''',
			[ username, salt, hash.toString('hex'), sessid, permissions, null ]
		)).id
		return sessid: sessid, id: id

	# Check if the given username-password pair is valid.
	# Returns true or false, or an error.
	accessGranted: async (name, password) ->
		userdata = await @db.oneOrNone '''
			SELECT password_salt, password_hash
			FROM account
			WHERE lower(name) = lower($1)
			''', name
		unless userdata
			return false  # Wrong username
		hash = await crypto.pbkdf2Async password, userdata.password_salt, 4096, 256, 'sha512'
		return (hash.toString('hex') is userdata.password_hash)

	update: (account) ->
		@db.none '''
			UPDATE account
			SET name=${name}, sessid=${sessid},
				reg_time=${reg_time}, sess_time=${sess_time},
				permissions=${permissions}, character_id=${character_id},
				email=${email}, email_confirmed=${email_confirmed}
			WHERE id = ${id}
			''', account

	updatePassword: async (id, password) ->
		salt = math.createSalt 16
		hash = await crypto.pbkdf2Async password, salt, 4096, 256, 'sha512'
		await @db.none 'UPDATE account SET password_salt = $1, password_hash = $2 WHERE id = $3', [salt, hash.toString('hex'), id]

	getEmailValidationCode: async (id) ->
		code = uuid.v4()
		await @db.none 'INSERT INTO email_confirmation (account_id, code) VALUES ($1, $2)', [id, code]
		await @db.none 'DELETE FROM email_confirmation WHERE account_id = $1 AND code != $2', [id, code]
		return code

	validateEmail: async (id, code) ->
		account = await @db.oneOrNone '''
			UPDATE account SET email_confirmed = TRUE
			WHERE account.id = $1
			  AND EXISTS (SELECT * FROM email_confirmation WHERE account_id = $1 AND code = $2)
			RETURNING id
			''', [id, code]
		unless account
			return false
		await @db.none 'DELETE FROM email_confirmation WHERE account_id = $1', id
		return true

	remove: (id) ->
		@db.none 'DELETE FROM account WHERE id = $1', id
