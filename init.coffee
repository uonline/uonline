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
lib = require './lib.js'
async = require 'async'
sync = require 'sync'
dashdash = require 'dashdash'

anyDB = null
createAnyDBConnection = (url) ->
	anyDB = require 'any-db' unless anyDB?
	anyDB.createConnection(url)


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
		'test-monsters'
		't'
	]
	type: 'bool'
	help: 'Insert test monsters.'
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
	status = if current < newest then 'needs update' else 'up to date'
	console.log "init.js with #{newest + 1} revisions on board."
	console.log "Current revision is #{current} (#{status})."


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
	lib.migration.migrate.sync null, dbConnection


optimize = ->
	conn = createAnyDBConnection(config.DATABASE_URL)
	db_name = config.DATABASE_URL.match(/[^\/]+$/)[0]

	result = conn.query.sync conn,
		"SELECT table_name "+
		"FROM information_schema.tables "+
		"WHERE table_schema = 'public'"  # move to subquery, maybe?

	for row in result.rows
		#lib.prettyprint.action "Optimizing table `#{row.table_name}`"
		console.log "Optimizing table `#{row.table_name}`..."
		try
			optRes = conn.query.sync conn, "VACUUM FULL ANALYZE #{row.table_name}"
			console.log "ok"
		catch ex
			console.trace ex


unifyValidate = ->
	console.log 'Coming soon...'


unifyExport = ->
	dbConnection = createAnyDBConnection(config.MYSQL_DATABASE_URL)
	locparse = require './lib/locparse'
	result = locparse.processDir('./unify/Кронт - kront', true)
	result.save(dbConnection)


insertTestMonsters = ->
	dbConnection = createAnyDBConnection(config.MYSQL_DATABASE_URL)
	prototypes = [
		[1, 'Гигантская улитка', 1, 1, 1, 1, 1, 1, 1, 1, 3]
		[2, 'Червь-хищник', 2, 1, 2, 2, 1, 1, 2, 1, 1]
		[3, 'Ядовитая многоножка', 1, 1, 2, 1, 1, 1, 1, 1, 1]
		[4, 'Скорпион', 1, 2, 1, 1, 1, 1, 1, 1, 1]
		[5, 'Кобра', 2, 1, 3, 1, 3, 2, 1, 2, 1]
		[6, 'Дикий кабан', 1, 2, 1, 2, 1, 1, 1, 2, 1]
		[7, 'Тарантул', 3, 1, 4, 2, 1, 2, 4, 1, 1]
	]
	for i in prototypes
		dbConnection.query.sync(
			dbConnection
			"REPLACE INTO `monster_prototypes` "+
				"(`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, "+
				"`wisdom`, `volition`, `health_max`, `mana_max`) "+
				"VALUES "+
				"(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
			i
		)
	monsters = [
		[1, 6, 774449300, 1, 1, null, 16]
		[2, 5, 648737395, 1, 1, null, 5]
		[3, 6, 580475724, 1, 1, null, 25]
		[4, 3, 571597042, 1, 1, null, 22]
		[5, 4, 845588419, 1, 1, null, 11]
		[6, 3, 446105458, 1, 1, null, 19]
		[7, 1, 4642136, 1, 1, null, 10]
		[8, 5, 29958182, 1, 1, null, 9]
		[9, 7, 904434466, 1, 1, null, 13]
		[10, 7, 288482442, 1, 1, null, 25]
		[11, 1, 77716864, 1, 1, null, 6]
		[12, 2, 701741103, 1, 1, null, 17]
		[13, 5, 744906885, 1, 1, null, 22]
		[14, 4, 744906885, 1, 1, null, 6]
		[15, 7, 4642136, 1, 1, null, 8]
		[16, 2, 1054697917, 1, 1, null, 7]
		[17, 6, 833637588, 1, 1, null, 10]
		[18, 6, 29958182, 1, 1, null, 25]
		[19, 6, 774449300, 1, 1, null, 12]
		[20, 4, 744906885, 1, 1, null, 8]
		[21, 5, 446105458, 1, 1, null, 22]
		[22, 5, 288482442, 1, 1, null, 17]
		[23, 1, 4642136, 1, 1, null, 8]
		[24, 7, 29958182, 1, 1, null, 16]
		[25, 5, 774449300, 1, 1, null, 15]
		[26, 7, 1054697917, 1, 1, null, 20]
		[27, 5, 723001325, 1, 1, null, 16]
		[28, 4, 571597042, 1, 1, null, 23]
		[29, 3, 845588419, 1, 1, null, 14]
		[30, 5, 288482442, 1, 1, null, 25]
		[31, 4, 701741103, 1, 1, null, 6]
		[32, 2, 77716864, 1, 1, null, 15]
		[33, 7, 701741103, 1, 1, null, 17]
		[34, 7, 701741103, 1, 1, null, 22]
		[35, 5, 772635195, 1, 1, null, 7]
		[36, 6, 29958182, 1, 1, null, 21]
		[37, 4, 29958182, 1, 1, null, 18]
		[38, 1, 578736465, 1, 1, null, 25]
		[39, 4, 172926385, 1, 1, null, 25]
		[40, 2, 744906885, 1, 1, null, 21]
		[41, 5, 29958182, 1, 1, null, 21]
		[42, 4, 723001325, 1, 1, null, 9]
		[43, 1, 451777421, 1, 1, null, 8]
		[44, 4, 29958182, 1, 1, null, 5]
		[45, 4, 648737395, 1, 1, null, 24]
		[46, 2, 723001325, 1, 1, null, 21]
		[47, 2, 571597042, 1, 1, null, 24]
		[48, 2, 288482442, 1, 1, null, 13]
		[49, 2, 774449300, 1, 1, null, 8]
		[50, 6, 446105458, 1, 1, null, 19]
	]
	for i in monsters
		dbConnection.query.sync(
			dbConnection
			"REPLACE INTO `monsters` "+
				"(`id`, `prototype`, `location`, `health`, `mana`, `effects`, `attack_chance`) "+
				"VALUES "+
				"(?, ?, ?, ?, ?, ?, ?)"
			i
		)


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
		optimize() if opts.optimize_tables
		unifyValidate() if opts.unify_validate
		unifyExport() if opts.unify_export
		insertTestMonsters() if opts.test_monsters
		process.exit 0
	(ex) ->
		if ex? then throw ex
)
