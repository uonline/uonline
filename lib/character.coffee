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

sync = require 'sync'
transaction = require 'any-db-transaction'


# Creates new character for user.
# Returns id of new character.
exports.createCharacter = ((dbConnection, user_id, name) ->
	tx = transaction dbConnection
	charid = tx.query.sync(tx,
		"INSERT INTO characters (name, player, location) "+
		"VALUES ($1, $2, (SELECT id FROM locations WHERE initial = 1)) RETURNING id",
		[ name, user_id ]).rows[0].id
	tx.query.sync(tx,
		"UPDATE uniusers SET character_id = $1 WHERE id = $2",
		[ charid, user_id ])
	tx.commit.sync(tx)
	return charid
).async()


# Removes character
exports.deleteCharacter = ((dbConnection, user_id, character_id) ->
	tx = transaction dbConnection

	tx.query.sync(tx,
		"UPDATE uniusers SET character_id = NULL WHERE id = $1 AND character_id = $2",
		[ user_id, character_id ])

	tx.query.sync(tx,
		"DELETE FROM armor WHERE owner = $1",
		[ character_id ])

	res = tx.query.sync(tx,
		"DELETE FROM characters WHERE id = $1 AND player = $2 "+
			"AND NOT EXISTS(SELECT * FROM battle_participants WHERE character_id = $1)", #must not be in battle
		[ character_id, user_id ])

	if res.rowCount == 0
		tx.rollback.sync(tx)
		return false
	else
		tx.commit.sync(tx)
		return true
).async()


# Switches user's character.
exports.switchCharacter = ((dbConnection, user_id, new_character_id) ->
	res = dbConnection.query.sync(dbConnection,
		"UPDATE uniusers SET character_id = $1 "+
		"WHERE id = $2 AND "+
			"EXISTS(SELECT * FROM characters WHERE id = $1 AND player = $2)",
		[ new_character_id, user_id ])

	if res.rowCount == 0
		throw new Error("User ##{user_id} doesn't have character ##{new_character_id}")

	return
).async()
