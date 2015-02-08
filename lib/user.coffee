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

config = require '../config.js'

crypto = require 'crypto'
async = require 'async'
sync = require 'sync'
transaction = require 'any-db-transaction'


# Check if a user with the given username exists.
# Returns true or false, or an error.
exports.userExists = (dbConnection, username, callback) ->
	dbConnection.query 'SELECT count(*) AS result FROM uniusers WHERE lower(username) = lower($1)',
		[username],
		(error, result) ->
			callback error, error or (result.rows[0].result > 0)


# Check if a user with the given id exists.
# Returns true or false, or an error.
exports.idExists = (dbConnection, id, callback) ->
	dbConnection.query 'SELECT count(*) AS result FROM uniusers WHERE id = $1', [id], (error, result) ->
		callback error, error or (result.rows[0].result > 0)


# Check if a session with the given sessid exists.
# Returns true or false, or an error.
exports.sessionExists = (dbConnection, sess, callback) ->
	dbConnection.query 'SELECT count(*) AS result FROM uniusers WHERE sessid = $1', [sess], (error, result) ->
		callback error, error or (result.rows[0].result > 0)


# Get information about a user with the given sessid.
# Takes session expiration time as an argument.
# Returns an object with fields:
# - loggedIn
# - isAdmin
# - {other user's fields}
#
# or an error.
exports.sessionInfoRefreshing = ((dbConnection, sessid, sess_timeexpire, asyncUpdate) ->
	unless sessid?
		return loggedIn: false

	user = dbConnection.query.sync(dbConnection,
		"SELECT uniusers.* "+
		"FROM uniusers "+
		"WHERE sessid = $1 "+
		"  AND sess_time > NOW() - $2 * INTERVAL '1 SECOND'",
		[sessid, sess_timeexpire]
	).rows[0]

	unless user
		return loggedIn: false

	if asyncUpdate is true
		process.nextTick ->
			dbConnection.query(
				'UPDATE uniusers SET sess_time = NOW() WHERE id = $1',
				[user.id],
				(error, result) ->
					if error?
						console.log 'Async update failed'
						console.log error.stack
			)
	else
		dbConnection.query.sync(dbConnection,
			'UPDATE uniusers SET sess_time = NOW() WHERE id = $1',
			[user.id]
		)

	user.loggedIn = true
	user.isAdmin = (user.permissions is 'admin')
	return user
).async()


exports.getFeatures = ((dbConnection, id_or_name) ->
	field = if typeof id_or_name is 'number' then 'uniusers.id' else 'username'
	
	user = dbConnection.query.sync(dbConnection,
		"SELECT uniusers.* "+
		"FROM uniusers "+
		"WHERE #{field} = $1",
		[id_or_name]
	).rows[0]
	
	unless user?
		return null
	
	user.isAdmin = (user.permissions is 'admin')
	return user
).async()


# Generate an unique sessid with the given length.
# Returns a string, or an error.
exports.generateSessId = ((dbConnection, sess_length) ->
	# check random sessid for uniqueness
	loop
		sessid = exports.createSalt(sess_length)
		exists = exports.sessionExists.sync null, dbConnection, sessid
		unless exists
			return sessid
	return
).async()


# Get user id using his sessid.
# Returns a number, or an error.
exports.idBySession = (dbConnection, sess, callback) ->
	dbConnection.query 'SELECT id FROM uniusers WHERE sessid = $1', [sess], (error, result) ->
		if result? and result.rows.length is 0
			error = new Error "Wrong user's id"
		callback error, error or result.rows[0].id


# Close a session with given sessid.
# Returns an error (if any), a string 'Not closing: empty sessid' (if it was empty), or nothing.
exports.closeSession = ((dbConnection, sessid) ->
	unless sessid?
		return 'Not closing: empty sessid'
	newSessid = exports.generateSessId.sync null, dbConnection, config.sessionLength
	dbConnection.query.sync dbConnection,
		'UPDATE uniusers SET sessid = $1 WHERE sessid = $2', [ newSessid, sessid ]
	return
).async()


# Generate a random sequence of printable characters with given length.
# Returns a string.
exports.createSalt = (length) ->
	dict = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	return (dict[Math.floor(Math.random() * dict.length)] for i in [0...length]).join('')


# Create a new user with given username, password and permissions (see config.js).
# Returns a string with sessid, or an error.
exports.registerUser = ((dbConnection, username, password, permissions) ->
	if exports.userExists.sync(null, dbConnection, username) is true
		throw new Error 'user already exists'
	salt = exports.createSalt(16)
	hash = crypto.pbkdf2.sync(null, password, salt, 4096, 256)
	sessid = exports.generateSessId.sync(null, dbConnection, config.sessionLength)
	
	tx = transaction dbConnection
	character_id = tx.query.sync(tx,
		'INSERT INTO characters (name, player, location) VALUES ('+
			'$1, '+
			'NULL, '+ # player is null for now, will update later
			'(SELECT id FROM locations WHERE initial = 1)'+
		') RETURNING id',
		[username]
	).rows[0].id
	user_id = tx.query.sync(tx,
		'INSERT INTO uniusers ('+
			'username, salt, hash, sessid, reg_time, sess_time, permissions, character_id'+
			') VALUES ('+
			'$1, $2, $3, $4, NOW(), NOW(), $5, $6'+
		') RETURNING id',
		[username, salt, hash.toString('hex'), sessid, permissions, character_id]
	).rows[0].id
	tx.query(
		'UPDATE characters SET player = $1 WHERE id = $2',
		[user_id, character_id]
	)
	tx.commit.sync(tx)
	return sessid: sessid
).async()


# Check if the given username-password pair is valid.
# Returns true or false, or an error.
exports.accessGranted = ((dbConnection, username, password, callback) ->
	userdata = dbConnection.query.sync dbConnection,
		'SELECT salt, hash FROM uniusers WHERE lower(username) = lower($1)', [username]
	if userdata.rows.length is 0
		return false  # Wrong username
	userdata = userdata.rows[0]
	hash = crypto.pbkdf2.sync null,
		password, userdata.salt, 4096, 256
	return (hash.toString('hex') is userdata.hash)
).async()


# Create a new session for user with given username.
# Returns a string with sessid, or an error.
exports.createSession = (dbConnection, username, callback) ->
	async.waterfall [
		(innerCallback) ->
			exports.generateSessId dbConnection, config.sessionLength, innerCallback
		(sessid, innerCallback) ->
			dbConnection.query 'UPDATE uniusers SET sess_time = NOW(), sessid = $1 '+
				'WHERE lower(username) = lower($2)',
				[sessid, username],
				(error, result) ->
					innerCallback error, result, sessid
	], (error, result, sessid) ->
		callback error, sessid
