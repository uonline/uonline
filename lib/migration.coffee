# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.	If not, see <http://www.gnu.org/licenses/>.


justMigrate = (dbConnection, revision, for_tables) ->
	migration = exports.getMigrationsData()[revision]
	for params in migration
		params = params.slice()
		#mb convert for_tables to hashmap?
		if for_tables and params[TABLE_NAME_COLUMN] not in for_tables
			continue
		try
			if params[FUNC_NAME_COLUMN] == 'rawsql'
				dbConnection.query.sync dbConnection, params[RAWSQL_COLUMN]
			else
				funcName = params.splice(FUNC_NAME_COLUMN, 1)[0]
				func = tables[funcName]
				params.unshift dbConnection
				params.unshift null
				func.sync.apply func, params
		catch ex
			throw new Error("While performing\n[#{params}]\n#{ex.toString()}\n#{ex.stack}")
	return

'use strict'
sync = require('sync')
tables = require('./tables')
TABLE_NAME_COLUMN = 0
FUNC_NAME_COLUMN = 1
RAWSQL_COLUMN = 2
migrationData = [
	[
		# create uniusers
		['uniusers', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'location INT DEFAULT 1, '+
			'permissions INT DEFAULT 0, '+
			'"user" TEXT, '+ # quotes for pg, see also #312
			'mail TEXT, '+
			'salt TEXT, '+
			'hash TEXT, '+
			'sessid TEXT, '+
			'sessexpire TIMESTAMPTZ, '+
			'reg_time TIMESTAMPTZ, '+

			'fight_mode INT DEFAULT 0, '+
			'autoinvolved_fm INT DEFAULT 0, '+
			'level INT DEFAULT 1, '+
			'health INT DEFAULT 200, '+
			'health_max INT DEFAULT 200, '+ #
			'mana INT DEFAULT 100, '+
			'mana_max INT DEFAULT 100, '+ #
			'energy INT DEFAULT 50, '+ #
			'power INT DEFAULT 3, '+ #
			'defense INT DEFAULT 3, '+ #
			'agility INT DEFAULT 3, '+ # ловкость
			'accuracy INT DEFAULT 3, '+ # точность
			'intelligence INT DEFAULT 5, '+ # интеллект
			'initiative INT DEFAULT 5, '+ # инициатива
			'exp INT DEFAULT 0, '+
			'effects TEXT']

		# create locations
		['locations', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'goto TEXT, '+
			'description TEXT, '+
			'area INT, '+
			'picture TEXT, '+
			'"default" SMALLINT DEFAULT 0']

		# create areas
		['areas', 'create', 'id INT, PRIMARY KEY (id), '+
			'title TEXT, '+
			'description TEXT']

		# create monster_prototypes
		['monster_prototypes', 'create', 'id SERIAL, PRIMARY KEY (id), '+
			'name TEXT, '+
			'level INT, '+
			'power INT, '+
			'agility INT, '+
			'endurance INT, '+ # --> defense
			'intelligence INT, '+
			'wisdom INT, '+ # --> accuracy
			'volition INT, '+ # --> initiative_min
			'health_max INT, '+
			'mana_max INT']# + energy

		# create monsters
		['monsters', 'create', 'incarn_id SERIAL, PRIMARY KEY (incarn_id), '+
			'id INT, '+
			'location INT, '+
			'health INT, '+
			'mana INT, '+
			'effects TEXT, '+
			'attack_chance INT']
	]
	[
		# make columns sane in monsters
		['monsters', 'renameCol', 'id', 'prototype']
		['monsters', 'renameCol', 'incarn_id', 'id']
	]
	[
		# now we store last action time instead of session expiration time
		['uniusers', 'renameCol', 'sessexpire', 'sess_time']
	]
	[
		# user -> username
		['uniusers', 'renameCol', '"user"', 'username']
	]
	[
		# index for sessid, otherwise it's too slow
		['uniusers', 'createIndex', 'sessid']
	]
	[
		# new system
		['monster_prototypes', 'addCol', 'energy INT']
		['monster_prototypes', 'renameCol', 'endurance', 'defense']
		['monster_prototypes', 'renameCol', 'wisdom', 'accuracy']
		['monster_prototypes', 'renameCol', 'volition', 'initiative_min']
		['monster_prototypes', 'addCol', 'initiative_max INT']
	]
	[
		# goto -> ways
		['locations', 'renameCol', 'goto', 'ways']
	]
	[
		# current initiative for monsters
		['monsters', 'addCol', 'initiative INT']
	]
	[
		# #410
		['locations', 'renameCol', '"default"', 'initial']
	]
	[
		['battles', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'location INT, '+
			'turn_number INT DEFAULT 0, '+
			'is_over INT DEFAULT 0']
		['battle_participants', 'create',
			'battle INT, '+
			'id INT, '+
			'kind TEXT, '+
			'index INT, '+
			'side INT']
	]
	[
		['creature_kind', 'createEnum', "'user', 'monster'"]
		['battle_participants', 'changeCol', 'kind', "creature_kind USING kind::creature_kind"]
	]
	[
		['permission_kind', 'createEnum', "'user', 'admin'"]
		['uniusers', 'rawsql', 'ALTER TABLE uniusers ALTER COLUMN permissions DROP DEFAULT']
		['uniusers', 'changeCol', 'permissions',
			"permission_kind USING "+
				"CASE WHEN permissions=0 THEN 'user'::permission_kind "+
				"                        ELSE 'admin'::permission_kind END"]
		['uniusers', 'rawsql', "ALTER TABLE uniusers ALTER COLUMN permissions SET DEFAULT 'user'"]
	]
	[
		['battles', 'dropCol', 'is_over']
		['uniusers', 'dropCol', 'fight_mode']
	]
	[
		['uniusers', 'changeDefault', 'health',       1000]
		['uniusers', 'changeDefault', 'health_max',   1000]
		['uniusers', 'changeDefault', 'mana',         500]
		['uniusers', 'changeDefault', 'mana_max',     500]
		['uniusers', 'changeDefault', 'energy',       100]
		['uniusers', 'changeDefault', 'power',        50]
		['uniusers', 'changeDefault', 'defense',      50]
		['uniusers', 'changeDefault', 'agility',      50]
		['uniusers', 'changeDefault', 'accuracy',     50]
		['uniusers', 'changeDefault', 'intelligence', 50]
		['uniusers', 'changeDefault', 'initiative',   50]
	]
	[
		['armor_prototypes', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'name TEXT, '+
			'type TEXT, '+
			'strength_max INT, '+
			'coverage INT']
		['armor', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'prototype INT, '+
			'owner INT, '+
			'strength INT']
	]
	[
		['armor', 'addCol', 'equipped BOOLEAN DEFAULT true']
	]
	[
		['characters', 'create',
			'id SERIAL, PRIMARY KEY (id), '+
			'name TEXT, '+
			
			'level INT DEFAULT 1, '+
			'exp INT DEFAULT 0, '+
			'health INT DEFAULT 1000, '+
			'health_max INT DEFAULT 1000, '+
			'mana INT DEFAULT 500, '+
			'mana_max INT DEFAULT 500, '+
			'energy INT DEFAULT 100, '+
			'power INT DEFAULT 50, '+
			'defense INT DEFAULT 50, '+
			'agility INT DEFAULT 50, '+
			'accuracy INT DEFAULT 50, '+
			'intelligence INT DEFAULT 50, '+
			'initiative INT DEFAULT 50, '+
			
			'player INT DEFAULT NULL, '+
			'location INT DEFAULT 1, '+
			'autoinvolved_fm BOOLEAN DEFAULT FALSE, '+
			'attack_chance INT DEFAULT -1']
		
		['characters', 'rawsql', # from uniusers
			'INSERT INTO characters ('+
				'name, level, exp, '+
				'health, health_max, mana, mana_max, '+
				'energy, power, defense, agility, accuracy, intelligence, initiative, '+
				'player, location, autoinvolved_fm) '+
			'(SELECT username, level, exp, '+
				'health, health_max, mana, mana_max, '+
				'energy, power, defense, agility, accuracy, intelligence, initiative, '+
				'id, location, autoinvolved_fm::boolean '+
			'FROM uniusers)']
		['characters', 'rawsql', # from monsters
			'INSERT INTO characters ('+
				'name, level, exp, '+
				'health, health_max, mana, mana_max, '+
				'energy, power, defense, agility, accuracy, intelligence, initiative, '+
				'player, location, autoinvolved_fm, attack_chance) '+
			'(SELECT name, level, 0, '+
				'health, health_max, mana, mana_max, '+
				'energy, power, defense, agility, accuracy, intelligence, initiative, '+
				'NULL, location, FALSE, attack_chance '+
			'FROM monsters, monster_prototypes AS proto '+
			'WHERE monsters.id = proto.id)']
		['uniusers', 'rawsql', # cleanup
			'ALTER TABLE uniusers '+
				('location autoinvolved_fm level health health_max mana mana_max '+
				'energy power defense agility accuracy intelligence initiative exp effects')
					.replace(/\s/g, ', ').replace(/(\w+)/g, 'DROP COLUMN $1')]
		['uniusers', 'addCol', 'character_id INT']
		['battle_participants', 'dropCol', 'kind']
		['battle_participants', 'renameCol', 'id', 'character_id']
		
		['battles', 'rawsql', 'TRUNCATE battles']
		['battle_participants', 'rawsql', 'TRUNCATE battle_participants']
		['armor', 'rawsql', 'TRUNCATE armor']
	]
]

exports.getMigrationsData = ->
	migrationData

#for testing
exports.setMigrationsData = (data) ->
	migrationData = data

exports.getNewestRevision = ->
	exports.getMigrationsData().length - 1

exports.getCurrentRevision = ((dbConnection, callback) ->
	try
		result = dbConnection.query.sync(dbConnection, 'SELECT revision FROM revision', [])
		return result.rows[0].revision
	catch error
		if error.code == 'ER_NO_SUCH_TABLE' or error.code == '42P01'
			return -1
		else
			throw error
).async()

exports.setRevision = ((dbConnection, revision, callback) ->
	dbConnection.query.sync dbConnection, 'CREATE TABLE IF NOT EXISTS revision (revision INT NOT NULL)', []
	dbConnection.query.sync dbConnection, 'DELETE FROM revision', []
	dbConnection.query.sync dbConnection, 'INSERT INTO revision VALUES ($1)', [ revision ]
	return
).async()

exports.migrateOne = ((dbConnection, revision) ->
	curRevision = exports.getCurrentRevision.sync(null, dbConnection)
	if curRevision == revision
		return
	if curRevision != revision - 1
		throw new Error('Can\'t migrate to revision <' + revision + '> from current <' + curRevision + '>')
	justMigrate dbConnection, revision
	exports.setRevision.sync null, dbConnection, revision
	return
).async()

exports.migrate = ((dbConnection, opts) ->
	opts = opts or {}
	unless opts.dest_revision?
		opts.dest_revision = Infinity

	opts.dest_revision = Math.min(opts.dest_revision, exports.getNewestRevision())
	for_tables = opts.tables or (if opts.table then [ opts.table ] else undefined)
	curRevision = exports.getCurrentRevision.sync(null, dbConnection)

	if curRevision < opts.dest_revision
		for i in [curRevision + 1 .. opts.dest_revision]
			if opts.verbose
				console.log 'Migrating ' + (if for_tables then "<#{for_tables}> " else '') + 'to revision ' + i
			justMigrate dbConnection, i, for_tables

	unless for_tables
		exports.setRevision.sync null, dbConnection, opts.dest_revision

	if opts.verbose
		console.log 'Migrated.'
	return
).async()

