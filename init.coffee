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
	mysqlConnection = createAnyDBConnection(config.MYSQL_DATABASE_URL)
	current = lib.migration.getCurrentRevision.sync(null, mysqlConnection)
	newest = lib.migration.getNewestRevision()
	status = if current < newest then 'needs update' else 'up to date'
	console.log "init.js with #{newest + 1} revisions on board."
	console.log "Current revision is #{current} (#{status})."


createDatabase = (arg) ->
	checkArgs arg, ['main', 'test', 'both']

	create = (db_url) ->
		[_, db_path, db_name] = db_url.match(/(.+)\/(.+)/)
		conn = createAnyDBConnection(db_path)
		try
			conn.query.sync(conn, 'CREATE DATABASE ' + db_name, [])
			console.log "#{db_name} created."
		catch error
			if error.code != 'ER_DB_CREATE_EXISTS'
				throw error
			console.log "#{db_name} already exists."

	create config.MYSQL_DATABASE_URL if arg in ['main', 'both']
	create config.MYSQL_DATABASE_URL_TEST if arg in ['test', 'both']


dropDatabase = (arg) ->
	checkArgs opts.drop_database, ['main', 'test', 'both']

	drop = (db_url, callback) ->
		[_, db_path, db_name] = db_url.match(/(.+)\/(.+)/)
		conn = createAnyDBConnection(db_path)
		try
			conn.query.sync(conn, 'DROP DATABASE ' + db_name, [])
			console.log "#{db_name} dropped."
		catch error
			if error.code != 'ER_DB_DROP_EXISTS'
				throw error
			console.log "#{db_name} already dropped."

	drop config.MYSQL_DATABASE_URL if arg in ['main', 'both']
	drop config.MYSQL_DATABASE_URL_TEST if arg in ['test', 'both']


migrateTables = ->
	mysqlConnection = createAnyDBConnection(config.MYSQL_DATABASE_URL)
	lib.migration.migrate.sync null, mysqlConnection


optimize = ->
	conn = createAnyDBConnection(config.MYSQL_DATABASE_URL)
	db_name = config.MYSQL_DATABASE_URL.match(/[^\/]+$/)[0]

	result = conn.query.sync conn,
		"SELECT TABLE_NAME "+
		"FROM information_schema.TABLES "+
		"WHERE TABLE_SCHEMA='#{db_name}'"

	for row in result.rows
		optRes = conn.query.sync conn, "OPTIMIZE TABLE #{row.TABLE_NAME}"
		console.log row.TABLE_NAME+":"

		for optRow in optRes.rows
			console.log "  #{optRow.Op} #{optRow.Msg_type}: #{optRow.Msg_text}"


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
		process.exit 0
	(ex) ->
		if ex? then throw ex
)
