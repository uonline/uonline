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

async = require 'asyncawait/async'
await = require 'asyncawait/await'
transaction = require 'any-db-transaction'
game = require '../lib/game.coffee'


# Check if a character with the given name exists.
# Returns true or false, or an error.
exports.characterExists = async (db, name, callback) ->
	result = await db.queryAsync 'SELECT count(*) AS result FROM characters WHERE lower(name) = lower($1)', [name]
	return result.rows[0].result > 0


# Creates new character for user.
# Returns id of new character.
exports.createCharacter = async (db, user_id, name, race, gender) ->
	if await exports.characterExists db, name
		throw new Error('character already exists')

	energies = {
		'orc-male': 220
		'orc-female': 200
		'human-male': 170
		'human-female': 160
		'elf-male': 150
		'elf-female': 140
	}
	energy = energies["#{race}-#{gender}"]
	charid = (await db.queryAsync(
		"INSERT INTO characters (name, player, location, race, gender, energy, energy_max) "+
		"VALUES ($1, $2, (SELECT id FROM locations WHERE initial = 1), $3, $4, $5, $5) RETURNING id",
		[ name, user_id, race, gender, energy ])).rows[0].id

	await db.queryAsync(
		"UPDATE uniusers SET character_id = $1 WHERE id = $2",
		[ charid, user_id ])
	return charid



# Removes character
exports.deleteCharacter = async (db, user_id, character_id, force=false) ->
	# do checks first

	res = await db.queryAsync "SELECT id FROM characters WHERE id = $1 AND player = $2", [character_id, user_id]

	if res.rowCount == 0
		return {
			result: 'fail'
			reason: "character ##{character_id} of user ##{user_id} not found"
		}

	unless force
		res = await db.queryAsync "SELECT battle FROM battle_participants WHERE character_id = $1", [character_id]

		if res.rowCount > 0
			return {
				result: 'fail'
				reason: "character ##{character_id} is in battle ##{res.rows[0].battle}"
			}

	# start deleting

	await game.goEscape(db, character_id)

	# if the character we delete is active, unselect it
	await db.queryAsync(
		"UPDATE uniusers SET character_id = NULL WHERE id = $1 AND character_id = $2", [ user_id, character_id ])

	await db.queryAsync "DELETE FROM items WHERE owner = $1", [ character_id ]

	await db.queryAsync "DELETE FROM characters WHERE id = $1 AND player = $2", [ character_id, user_id ]

	return { result: 'ok' }



# Switches user's character.
exports.switchCharacter = async (db, user_id, new_character_id) ->
	res = await db.queryAsync(
		"UPDATE uniusers SET character_id = $1 "+
		"WHERE id = $2 AND "+
			"EXISTS(SELECT * FROM characters WHERE id = $1 AND player = $2)",
		[ new_character_id, user_id ])

	if res.rowCount == 0
		throw new Error("user ##{user_id} doesn't have character ##{new_character_id}")
	return true
