{async, await} = require 'asyncawait'
path = require 'path'

User = require path.resolve(__dirname) + '/../../user'


class UserPG extends User
	constructor: (@db) ->

	# Generate a random sequence of printable characters with given length.
	# Returns a string.
	createSalt: (length) ->
		dict = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
		return (dict[Math.floor(Math.random() * dict.length)] for i in [0...length]).join('')

	# Generate an unique sessid with the given length.
	# Returns a string, or an error.
	generateSessId: async (sess_length) ->
		# check random sessid for uniqueness
		loop
			sessid = @_createSalt(sess_length)
			unless await @existsSessid(sessid)
				return sessid

	existsID: (id) ->
		db.one("SELECT count(*) FROM users WHERE id = $1", id).then(res -> res.count)

	byID: (id) ->
		db.one("SELECT * FROM users WHERE id = $1", id)

	existsName: (username) ->
		@db.one("SELECT count(*)::int FROM uniusers WHERE lower(username) = lower($1)", username).then((res) -> res.count > 0)

	byName: (username) ->
		@db.oneOrNone("SELECT * FROM uniusers WHERE lower(username) = lower($1)", username)

	existsSessid: (sessid) ->
		#

	create: async (username, password, permissions) ->
		if await @existsName(username)
			throw new Error 'user already exists'

		salt = @_createSalt 16
		hash = await crypto.pbkdf2Async password, salt, 4096, 256, 'sha512'
		sessid = await @_generateSessId config.sessionLength

		user_id = (await db.one(
			'INSERT INTO uniusers ('+
				'username, salt, hash, sessid, reg_time, sess_time, permissions, character_id'+
				') VALUES ('+
				'$1, $2, $3, $4, NOW(), NOW(), $5, $6'+
			') RETURNING id',
			[ username, salt, hash.toString('hex'), sessid, permissions, null ]
		)).id
		return sessid: sessid, userid: user_id

	# Check if the given username-password pair is valid.
	# Returns true or false, or an error.
	accessGranted: async (username, password) ->
		userdata = await @db.oneOrNone 'SELECT salt, hash FROM uniusers WHERE lower(username) = lower($1)', [username] #???
		unless userdata
			return false  # Wrong username
		hash = await crypto.pbkdf2Async password, userdata.salt, 4096, 256, 'sha512'
		return (hash.toString('hex') is userdata.hash)

	update: (user) ->
	updatePassword: (id, password) ->
	delete: (user) ->

module.exports = UserPG
