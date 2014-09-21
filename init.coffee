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

config = require './config.js'
lib = require './lib.coffee'
sync = require 'sync'
dashdash = require 'dashdash'
chalk = require 'chalk'


anyDB = null
createAnyDBConnection = (url) ->
	anyDB = require 'any-db' unless anyDB?
	anyDB.createConnection(url)

createQueryUtils = (url) ->
	lib.query_utils.getFor createAnyDBConnection url


checkError = (error, dontExit) ->
	if error?
		console.error error
		unless dontExit then process.exit 1


checkArgs = (passed, available) ->
	unless passed in available
		console.error "Unknown argument: #{passed}"
		console.error "Available: #{available}"
		process.exit 1


options = [
	names: [
		'help'
		'h'
	]
	type: 'bool'
	help: 'Print this help and exit.'
,
	names: [
		'info'
		'i'
	]
	type: 'bool'
	help: 'Show current revision and status.'
,
	names: [
		'create-database'
		'C'
	]
	type: 'string'
	help: 'Create database: "main", "test" or "both".'
,
	names: [
		'drop-database'
		'D'
	]
	type: 'string'
	help: 'Drop database: "main", "test" or "both".'
,
	names: [
		'migrate-tables'
		'm'
	]
	type: 'bool'
	help: 'Migrate to the latest revision.'
,
	names: [
		'optimize-tables'
		'o'
	]
	type: 'bool'
	help: 'Optimize tables.'
,
	names: [
		'unify-validate'
		'u'
	]
	type: 'bool'
	help: 'Validate locations.'
,
	names: [
		'unify-export'
		'U'
	]
	type: 'bool'
	help: 'Parse and save locations to DB.'
,
	names: [
		'monsters'
		'M'
	]
	type: 'bool'
	help: 'Insert monsters.'
,
	names: [
		'armor'
		'A'
	]
	type: 'bool'
	help: 'Insert armor (or update if already inserted).'
,
	names: [
		'give-armor'
		'a'
	]
	type: 'integer'
	help: 'Give some armor to user.'
,
	names: [
		'fix-attributes'
	]
	type: 'bool'
	help: 'Set predefined attributes for all players.'
]


parser = dashdash.createParser(options: options)

try
	opts = parser.parse process.argv
catch exception
	console.error 'error: ' + exception.message
	process.exit 1

if opts._args.length > 0
	console.error "error: unexpected argument '#{opts._args[0]}'"
	process.exit 1

if opts._order.length is 0
	opts.help = true
	opts._order.push(key: 'help', value: true, from: 'argv')

# Some other schema:
#  'help', 'h', 'Show this text'
#  'info', 'i', 'Show current revision and status'
#  'tables', 't', 'Migrate tables to the last revision'
#  'unify-validate', 'l', 'Validate unify files'
#  'unify-export', 'u', 'Parse unify files and push them to database'
#  'optimize', 'o', 'O', 'Optimize tables'
#  'test-monsters', 'm', 'Insert test monsters'
#  'drop', 'd', 'Drop all tables and set revision to -1'
# [--database] [--tables] [--unify-validate] [--unify-export] [--optimize] [--test-monsters] [--drop]

help = ->
	console.log "\nUsage: coffee init.coffee <commands>\n\n#{parser.help(includeEnv: true).trimRight()}"


info = ->
	dbConnection = createAnyDBConnection(config.DATABASE_URL)
	current = lib.migration.getCurrentRevision.sync(null, dbConnection)
	newest = lib.migration.getNewestRevision()

	status = 'up to date'
	color = chalk.green
	if current < newest
		status = 'needs update'
		color = chalk.red
	if current > newest
		status = "oh fuck, how it's possible?"
		color = chalk.red

	console.log "This is the uonline init script."
	console.log "Latest revision is #{chalk.magenta(newest)}, current is #{color(current)} (#{color(status)})."


createDatabase = (arg) ->
	checkArgs arg, ['main', 'test', 'both']

	create = (db_url) ->
		[_, db_path, db_name] = db_url.match(/(.+)\/(.+)/)
		db_path += '/postgres'  # PostgreSQL requires database to be specified.
		conn = createAnyDBConnection(db_path)
		try
			conn.query.sync(conn, "CREATE DATABASE #{db_name}", [])
			console.log "#{db_name} created."
		catch error
			if error.code is 'ER_DB_CREATE_EXISTS' or error.code is '42P04'  # MySQL, PostgreSQL
				console.log "#{db_name} already exists."
			else
				throw error

	create config.DATABASE_URL if arg in ['main', 'both']
	create config.DATABASE_URL_TEST if arg in ['test', 'both']


dropDatabase = (arg) ->
	checkArgs opts.drop_database, ['main', 'test', 'both']

	drop = (db_url, callback) ->
		[_, db_path, db_name] = db_url.match(/(.+)\/(.+)/)
		db_path += '/postgres'  # PostgreSQL requires database to be specified.
		conn = createAnyDBConnection(db_path)
		try
			conn.query.sync(conn, "DROP DATABASE #{db_name}", [])
			console.log "#{db_name} dropped."
		catch error
			if error.code is 'ER_DB_DROP_EXISTS' or error.code is '3D000'  # MySQL, PostgreSQL
				console.log "#{db_name} does not exist."
			else
				throw error

	drop config.DATABASE_URL if arg in ['main', 'both']
	drop config.DATABASE_URL_TEST if arg in ['test', 'both']


migrateTables = ->
	dbConnection = createAnyDBConnection(config.DATABASE_URL)
	lib.migration.migrate.sync null, dbConnection, {verbose: true}


optimize = ->
	console.log chalk.magenta 'Optimizing tables...'

	conn = createAnyDBConnection(config.DATABASE_URL)
	db_name = config.DATABASE_URL.match(/[^\/]+$/)[0]

	result = conn.query.sync conn,
		"SELECT table_name "+
		"FROM information_schema.tables "+
		"WHERE table_schema = 'public'"  # move to subquery, maybe?

	for row in result.rows
		#lib.prettyprint.action "Optimizing table `#{row.table_name}`"
		process.stdout.write " `#{row.table_name}`... "
		try
			optRes = conn.query.sync conn, "VACUUM FULL ANALYZE #{row.table_name}"
			console.log chalk.green "ok"
		catch ex
			console.log chalk.red.bold "fail"
			console.trace ex


unifyValidate = ->
	console.log 'Coming soon...'


unifyExport = ->
	dbConnection = createAnyDBConnection(config.DATABASE_URL)
	locparse = require './lib/locparse'
	result = locparse.processDir('./unify/Кронт - kront', true)
	result.save(dbConnection)


insertMonsters = ->
	dbConnection = createAnyDBConnection(config.DATABASE_URL)

	console.log('Inserting test prototypes...')

	prototypes = [
		[0,"Могильный жук",1,12,6,22,0,10,250,0,0,5,16]
		[1,"Молодой паук",2,16,30,20,0,26,290,0,0,10,30]
		[2,"Маленький скорпион",3,20,30,38,0,44,100,0,0,25,45]
		[3,"Паук",3,20,24,28,0,24,400,0,0,15,25]
		[4,"Хряк",5,28,16,30,0,22,540,0,0,9,20]
		[5,"Скелет",4,32,34,10,0,34,600,0,0,45,55]
		[6,"Молодой лесной волк",5,40,34,38,0,34,700,0,0,35,65]
		[7,"Малый медведь",6,56,34,68,0,30,800,0,0,24,44]
		[8,"Зомби",6,40,54,28,0,64,700,0,0,45,75]
		[9,"Броненосец",7,46,10,98,0,24,2500,0,0,15,25]
		[10,"Вепрь",8,80,30,28,0,24,1500,0,0,25,45]
		[11,"Лесной волк",9,68,54,54,0,44,1600,0,0,55,70]
		[12,"Медведь",10,160,22,128,0,48,2000,0,0,25,56]
		[13,"Гоблин",11,40,64,28,0,64,1100,0,0,25,45]
		[14,"Огр",14,180,30,118,0,44,1800,0,0,15,45]
		[15,"Грязевой голем",21,300,20,100,0,50,2500,0,0,5,16]
	]

	dbConnection.query.sync(dbConnection, "TRUNCATE monster_prototypes", [])
	for i in prototypes
		dbConnection.query.sync(
			dbConnection
			"INSERT INTO monster_prototypes "+
				"(id, name, level, power, agility, defense, intelligence, accuracy, "+
				"health_max, mana_max, energy, initiative_min, initiative_max) "+
				"VALUES "+
				"($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"
			i
		)

	console.log('Inserting monsters...')

	locs = dbConnection.query.sync(dbConnection, "SELECT id FROM locations").rows
	if (locs.length == 0)
		throw new Error("No locations found. Forgot unify data?")

	dbConnection.query.sync(dbConnection, "TRUNCATE monsters", [])
	prototypesFromDB = dbConnection.query.sync(dbConnection, "SELECT * FROM monster_prototypes").rows
	for i in [0...50]
		soul = prototypesFromDB.pickRandom()
		dbConnection.query.sync(
			dbConnection
			"INSERT INTO monsters "+
				"(id, prototype, location, health, mana, effects,"+
				" attack_chance, initiative) "+
				"VALUES "+
				"($1, $2, $3, $4, $5, $6, $7, $8)"
			[
				i, soul.id, locs.pickRandom().id, soul.health_max, soul.mana_max, null,
				Number.irandom(25), Number.irandom(soul.initiative_min, soul.initiative_max)
			]
		)

	console.log('Done.')


insertArmor = ->
	query = createQueryUtils(config.DATABASE_URL)
	
	prototypes = [
		[1 , 'кожаный нагрудник',  'breastplate',   40, 12]
		[2 , 'кожаные поножи',     'greave',        35, 20]
		[3 , 'кожаные сапоги',     'shoe',          20, 8]
		[4 , 'кожаные наплечники', 'pauldron',      20, 6]
		[5 , 'кожаные наручи',     'vambrace',      30, 6]
		[6 , 'кожаный шлем',       'helmet',        30, 8]
	]
	
	console.log('Inserting armor prototypes...')
	
	for proto in prototypes
		rows = query.all(
			'UPDATE armor_prototypes '+
			'SET name=$2, type=$3, strength_max=$4, coverage=$5 '+
			'WHERE id=$1 RETURNING id', proto)
		if rows.length is 0
			query(
				'INSERT INTO armor_prototypes (id, name, type, strength_max, coverage) '+
				'VALUES ($1, $2, $3, $4, $5)', proto)
	
	console.log('Done.')


giveArmor = (userid) ->
	query = createQueryUtils(config.DATABASE_URL)
	armorToGive = [1,2,3,4,5,6]
	
	actualCount = +query.val "SELECT count(*) FROM armor_prototypes WHERE id IN (#{armorToGive.join()})"
	if actualCount != armorToGive.length
		console.log("Didn't find all nesessary armor prototypes. Forgot to insert armor?")
		return
	
	user = query.row 'SELECT username FROM uniusers WHERE id = $1', [userid]
	
	console.log("Giving some armor to <#{user.username}>")
	
	for id in armorToGive
		strength = query.val 'SELECT strength_max FROM armor_prototypes WHERE id = $1', [id]
		query 'INSERT INTO armor (prototype, owner, strength) VALUES ($1, $2, $3)', [id, userid, strength]
	
	console.log('Done.')


fixAttrs = ->
	# ['uniusers', 'changeDefault', 'health',       1000],
	# ['uniusers', 'changeDefault', 'health_max',   1000],
	# ['uniusers', 'changeDefault', 'mana',         500],
	# ['uniusers', 'changeDefault', 'mana_max',     500],
	# ['uniusers', 'changeDefault', 'energy',       100],
	# ['uniusers', 'changeDefault', 'power',        50],
	# ['uniusers', 'changeDefault', 'defense',      50],
	# ['uniusers', 'changeDefault', 'agility',      50],
	# ['uniusers', 'changeDefault', 'accuracy',     50],
	# ['uniusers', 'changeDefault', 'intelligence', 50],
	# ['uniusers', 'changeDefault', 'initiative',   50],
	process.stdout.write chalk.magenta 'Setting predefined attributes... '
	dbConnection = createAnyDBConnection(config.DATABASE_URL)
	dbConnection.query.sync(
		dbConnection
		'UPDATE uniusers SET '+
			'health = 1000, '+
			'health_max = 1000, '+
			'mana = 500, '+
			'mana_max = 500, '+
			'energy = 100, '+
			'power = 50, '+
			'defense = 50, '+
			'agility = 50, '+
			'accuracy = 50, '+
			'intelligence = 50, '+
			'initiative = 50'
	)
	console.log chalk.green 'ok'



sync(
	->
		if opts.help
			help()
			process.exit 2

		if opts.info
			info()
			process.exit 0

		dropDatabase(opts.drop_database) if opts.drop_database
		createDatabase(opts.create_database) if opts.create_database
		migrateTables() if opts.migrate_tables
		unifyValidate() if opts.unify_validate
		unifyExport() if opts.unify_export
		insertMonsters() if opts.monsters
		optimize() if opts.optimize_tables
		fixAttrs() if opts.fix_attributes
		insertArmor() if opts.armor
		giveArmor(opts.give_armor) if opts.give_armor
		process.exit 0
	(ex) ->
		if ex? then throw ex
)
