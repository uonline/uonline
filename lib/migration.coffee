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


'use strict'

sync = require 'sync'
chalk = require 'chalk'
tables = require '../lib/tables.coffee'
qu = require '../lib/query_utils.coffee'

TABLE_NAME_COLUMN = 0
FUNC_NAME_COLUMN = 1
RAWSQL_COLUMN = 2

exports._justMigrate = (dbConnection, revision, for_tables, verbose) ->
	migration = exports.getMigrationsData()[revision]
	for params in migration
		params = params.slice()

		t1 = params.map (x) -> x
		if params[FUNC_NAME_COLUMN] is 'rawsql' then t1[FUNC_NAME_COLUMN] = 'SQL'
		t2 = t1.slice(2).join ' -> '  # should be ', ', but this one looks better and works for current stuff
		# maybe -> only if 2 arguments, dunno
		if verbose
			process.stdout.write "    Performing #{t1[FUNC_NAME_COLUMN]} on #{t1[TABLE_NAME_COLUMN]}: #{t2}..."

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
			throw new Error("While performing #{funcName} \n[#{params}]\n#{ex.toString()}\n#{ex.stack}")
		if verbose
			console.log " #{chalk.green 'ok'}"
	return


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
	[
		['uniusers', 'rawsql',
			'UPDATE uniusers '+
			'SET character_id = (SELECT id FROM characters WHERE player = uniusers.id)'],
		['characters', 'rawsql',
			'DELETE FROM characters WHERE player IS NULL']
		['characters', 'rawsql',
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
			'WHERE monsters.prototype = proto.id)']
	]
	[
		['characters', 'addCol', 'energy_max INT DEFAULT 220']
		['characters', 'rawsql', 'UPDATE characters SET energy_max = energy']
	]
	[
		['characters', 'rawsql',
			'CREATE UNIQUE INDEX players_character_unique_name_index '+
			'ON characters (name) WHERE player IS NOT NULL']
	]
	[
		# Rename armor to items
		['armor', 'rawsql', 'ALTER TABLE armor RENAME TO items']
		['armor_prototypes', 'rawsql', 'ALTER TABLE armor_prototypes RENAME TO items_proto']
	]
	[
		# Add damage (right now it's for shields)
		['items_proto', 'addCol', 'damage INT']
	]
	[
		# Types and columns for race and gender
		['characters', 'rawsql', "CREATE TYPE uonline_race AS ENUM ('orc', 'human', 'elf')"]
		['characters', 'rawsql', "CREATE TYPE uonline_gender AS ENUM ('male', 'female')"]
		['characters', 'addCol', 'race uonline_race']
		['characters', 'addCol', 'gender uonline_gender']
		['characters', 'rawsql', "UPDATE characters SET race='orc', gender='male' WHERE player IS NOT NULL"]
	]
	[
		# Fix energy for old characters
		['characters', 'rawsql',
			"UPDATE characters SET energy = 220, energy_max = 220 WHERE race = 'orc' AND gender = 'male'"]
		['characters', 'rawsql',
			"UPDATE characters SET energy = 200, energy_max = 200 WHERE race = 'orc' AND gender = 'female'"]
		['characters', 'rawsql',
			"UPDATE characters SET energy = 170, energy_max = 170 WHERE race = 'human' AND gender = 'male'"]
		['characters', 'rawsql',
			"UPDATE characters SET energy = 160, energy_max = 160 WHERE race = 'human' AND gender = 'female'"]
		['characters', 'rawsql',
			"UPDATE characters SET energy = 150, energy_max = 150 WHERE race = 'elf' AND gender = 'male'"]
		['characters', 'rawsql',
			"UPDATE characters SET energy = 140, energy_max = 140 WHERE race = 'elf' AND gender = 'female'"]
	]
	[
		# Weapon classes
		['items', 'rawsql',
			"CREATE TYPE uonline_weapon_class AS ENUM ('short', 'normal', 'chain', 'heavy')"]
		['items_proto', 'addCol', 'class uonline_weapon_class']
	]
	[
		# Weapon kind
		['items', 'rawsql', "CREATE TYPE uonline_weapon_kind AS ENUM "+
			"('bow','sword','mace','axe','staff','sphere','dagger','scythe','spear','hammer')"]
		['items_proto', 'addCol', 'kind uonline_weapon_kind']
	]
	[
		# Armor classes
		['uonline_armor_class', 'createEnum',
			"'cloth', 'light leather', 'leather', 'bone', "+
			"'mail', 'lamellar', 'light plate', 'plate', 'heavy plate'"]
		['items_proto', 'addCol', 'armor_class uonline_armor_class']
	]
	[
		['locations', 'changeCol', 'ways',
		"""json USING (
			'[' ||
			replace(
				regexp_replace(
					replace(ways, '"', '\\"'),
					'([^|=]+)=(\\d+)',
					'{"target":\\2, "text":"\\1"}',
					'g'
				),
				'|',
				', '
			) ||
			']')::json"""]
		['locations', 'changeDefault', 'ways', "'[]'::json"]
		['locations', 'rawsql', 'ALTER TABLE locations ALTER COLUMN ways SET NOT NULL']
	]
]

exports.getMigrationsData = ->
	migrationData

#for testing
exports.setMigrationsData = (data) ->
	migrationData = data

exports.getNewestRevision = ->
	exports.getMigrationsData().length - 1

exports.getCurrentRevision = ((dbConnection) ->
	if tables.tableExists.sync(null, dbConnection, 'revision')
		result = dbConnection.query.sync(dbConnection, 'SELECT revision FROM revision', [])
		return result.rows[0].revision
	else
		return -1
).async()

exports.setRevision = ((dbConnection, revision) ->
	dbConnection.query.sync dbConnection, 'CREATE TABLE IF NOT EXISTS revision (revision INT NOT NULL)', []
	dbConnection.query.sync dbConnection, 'DELETE FROM revision', []
	dbConnection.query.sync dbConnection, 'INSERT INTO revision VALUES ($1)', [ revision ]
	return
).async()

exports.migrate = ((dbConnection, opts = {}) ->
	unless opts.dest_revision?
		opts.dest_revision = Infinity

	opts.dest_revision = Math.min(opts.dest_revision, exports.getNewestRevision())
	for_tables = opts.tables or (if opts.table then [ opts.table ] else undefined)
	curRevision = exports.getCurrentRevision.sync(null, dbConnection)

	if curRevision < opts.dest_revision
		for i in [curRevision + 1 .. opts.dest_revision]
			if opts.verbose
				console.log chalk.magenta '  Migrating ' +
					(if for_tables then "<#{for_tables}> " else '') + 'to revision ' + i + '...'
			qu.doInTransaction dbConnection, (tx) ->
				exports._justMigrate tx, i, for_tables, !!opts.verbose
				unless for_tables
					exports.setRevision.sync null, tx, i
		if opts.verbose
			console.log chalk.green "  Success, migrated from #{chalk.blue curRevision} to "+
				"#{chalk.blue opts.dest_revision}."
	else
		if opts.verbose
			console.log '  No action needed.'

	return
).async()

