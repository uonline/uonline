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


# Check if a user with the given username exists.
# Returns true or false, or an error.
exports.userExists = (dbConnection, username, callback) ->
	dbConnection.query "SELECT count(*) AS result FROM `uniusers` WHERE user = ?", [username], (error, result) ->
		callback error, error or (result.rows[0].result > 0)


# Check if a user with the given id exists.
# Returns true or false, or an error.
exports.idExists = (dbConnection, id, callback) ->
	dbConnection.query "SELECT count(*) AS result FROM `uniusers` WHERE `id`= ?", [id], (error, result) ->
		callback error, error or (result.rows[0].result > 0)


# Check if a session with the given sessid exists.
# Returns true or false, or an error.
exports.sessionExists = (dbConnection, sess, callback) ->
	dbConnection.query "SELECT count(*) AS result FROM `uniusers` WHERE `sessid` = ?", [sess], (error, result) ->
		callback error, error or (result.rows[0].result > 0)


# Get information about a user with the given sessid.
# Takes session expiration time as an argument.
# Returns an object with fields:
# - sessionIsActive
# - username
# - admin
# - userid,
#
# or an error.
exports.sessionInfoRefreshing = (dbConnection, sessid, sess_timeexpire, callback) ->
	unless sessid?
		callback null, sessionIsActive: false
		return
	async.auto
		getUser: (callback) ->
			dbConnection.query("SELECT id, user, permissions FROM uniusers " +
				"WHERE sessid = ? AND sess_time > NOW() - INTERVAL ? SECOND",
				[ sessid, sess_timeexpire ], callback)
			return
		refresh: [
			"getUser"
			(callback, results) ->
				if results.getUser.rowCount is 0
					callback null, "session does not exist or expired"
					return
				dbConnection.query "UPDATE `uniusers` SET `sess_time` = NOW() WHERE `sessid` = ?",
					[sessid], callback
		]
	, (error, results) ->
		if error?
			callback error, null
			return
		if results.refresh is "session does not exist or expired"
			callback null, sessionIsActive: false
			return
		callback null,
			sessionIsActive: true
			username: results.getUser.rows[0].user
			admin: (results.getUser.rows[0].permissions is config.PERMISSIONS_ADMIN)
			userid: results.getUser.rows[0].id
		return
	return


# Generate an unique sessid with the given length.
# Returns a string, or an error.
exports.generateSessId = (dbConnection, sess_length, callback) ->
	# check random sessid for uniqueness
	(iteration = ->
		sessid = exports.createSalt(sess_length)
		exports.sessionExists dbConnection, sessid, (error, exists) ->
			if error?
				callback error, null
				return
			if exists
				iteration()
				return
			callback null, sessid
			return
		return
	)()
	return


# Get user id using his sessid.
# Returns a number, or an error.
exports.idBySession = (dbConnection, sess, callback) ->
	dbConnection.query "SELECT `id` FROM `uniusers` WHERE `sessid` = ?", [sess], (error, result) ->
		if result? and result.rowCount is 0
			error = "Wrong user's id"
		callback error, error or result.rows[0].id


# Close a session with given sessid.
# Returns an error (if any), a string 'Not closing: empty sessid' (if it was empty), or nothing.
exports.closeSession = (dbConnection, sessid, callback) ->
	unless sessid?
		callback null, 'Not closing: empty sessid'
		return
	exports.generateSessId dbConnection, config.sessionLength, (error, newSessid) ->
		if error?
			callback error
			return
		else
			dbConnection.query 'UPDATE `uniusers` SET `sessid` = ? WHERE `sessid` = ?',
				[ newSessid, sessid ], callback


# Generate a random sequence of printable characters with given length.
# Returns a string.
exports.createSalt = (length) ->
	dict = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
	return (dict[Math.floor(Math.random() * dict.length)] for i in [0...length]).join('')


# Create a new user with given username, password and permissions (see config.js).
# Returns a string with sessid, or an error.
exports.registerUser = (dbConnection, user, password, permissions, callback) ->
	salt = exports.createSalt(16)
	async.waterfall [
		(innerCallback) ->
			crypto.pbkdf2 password, salt, 4096, 256, innerCallback
		(hash, innerCallback) ->
			exports.generateSessId dbConnection, config.sessionLength, (error, result) ->
				innerCallback error, hash, result
				return
		(hash, sessid, innerCallback) -> #console.log("reg", hash.toString('hex'))
			dbConnection.query("INSERT INTO `uniusers` (" +
				"`user`, `salt`, `hash`, `sessid`, `reg_time`, `sess_time`, " + "`location`, `permissions`" +
				") VALUES (" +
				"?, ?, ?, ?, NOW(), NOW(), " +
				"(SELECT `id` FROM `locations` WHERE `default` = 1), ?" +
				")",
				[ user, salt, hash.toString("hex").substr(0, 255), sessid, permissions ], (error, result) ->
					innerCallback error, error or sessid: sessid
					return
			)
	], callback
	return


# Check if the given username-password pair is valid.
# Returns true or false, or an error.
exports.accessGranted = (dbConnection, user, password, callback) ->
	async.waterfall [
		(innerCallback) ->
			dbConnection.query "SELECT salt, hash FROM uniusers WHERE user = ?", [user], (error, result) ->
				if !!result and result.rowCount is 0
					callback null, false #Wrong user's name
					return
				innerCallback error, error or result.rows[0]
				return
		(result, innerCallback) ->
			crypto.pbkdf2 password, result.salt, 4096, 256, (error, hash) ->
				if result.hash is hash.toString("hex").substr(0, 255)
					callback null, true
				else
					callback null, false #Wrong user's pass
				return
	], (error, result) ->
		callback error, result
		return
	return


# Create a new session for user with given username.
# Returns a string with sessid, or an error.
exports.createSession = (dbConnection, username, callback) ->
	async.waterfall [
		(innerCallback) ->
			exports.generateSessId dbConnection, config.sessionLength, innerCallback
		(sessid, innerCallback) ->
			dbConnection.query "UPDATE uniusers " + "SET sess_time = NOW(), sessid = ? " + "WHERE user = ?", [
				sessid
				username
			], (error, result) ->
				innerCallback error, result, sessid
				return
	], (error, result, sessid) ->
		callback error, sessid
		return
	return
