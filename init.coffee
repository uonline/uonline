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

checkError = (error, dontExit) ->
	if error?
		console.error error
		unless dontExit then process.exit 1

checkArgs = (passed, avaliable) ->
	if (avaliable.indexOf passed) == -1
		console.log "Unknown arguent: #{passed}"
		console.log "Avaliable: #{avaliable}"
		process.exit 1

config = require './config.js'
utils = require './utils.js'
async = require 'async'
dashdash = require 'dashdash'


createDatabase = (arg, callback) ->
	checkArgs opts.create_database, ['main', 'test', 'both']
	
	create = (db_url, callback) ->
		db_path = db_url.match(/.+\//)[0]
		db_name = db_url.match(/[^\/]+$/)[0]
		conn = anyDB.createConnection(db_path)
		conn.query 'CREATE DATABASE ' + db_name, [], (error, result) ->
			if error?
				if error.code != 'ER_DB_CREATE_EXISTS'
					callback error
					return
				console.log "#{db_name} already exists."
			else
				console.log "#{db_name} created."
			callback null
	
	funcs = []
	funcs.push((callback) -> create config.MYSQL_DATABASE_URL, callback) if arg is 'main' or arg is 'both'
	funcs.push((callback) -> create config.MYSQL_DATABASE_URL_TEST, callback) if arg is 'test' or arg is 'both'
	
	async.parallel funcs, callback


dropDatabase = (arg, callback) ->
	checkArgs opts.drop_database, ['main', 'test', 'both']
	
	drop = (db_url, callback) ->
		db_path = db_url.match(/.+\//)[0]
		db_name = db_url.match(/[^\/]+$/)[0]
		conn = anyDB.createConnection(db_path)
		conn.query 'DROP DATABASE ' + db_name, [], (error, result) ->
			if error?
				if error.code != 'ER_DB_DROP_EXISTS'
					callback error
					return
				console.log "#{db_name} already dropped."
			else
				console.log "#{db_name} dropped."
			callback null
	
	funcs = []
	funcs.push((callback) -> drop config.MYSQL_DATABASE_URL, callback) if arg is 'main' or arg is 'both'
	funcs.push((callback) -> drop config.MYSQL_DATABASE_URL_TEST, callback) if arg is 'test' or arg is 'both'
	
	async.parallel funcs, callback


migrateTables = (callback) ->
	mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL)
	utils.migration.migrate mysqlConnection, callback


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
	action: createDatabase
,
	names: [
		'drop-database'
		'D'
	]
	type: 'string'
	help: 'Drop database: "main", "test" or "both".'
	action: dropDatabase
,
	names: [
		'migrate-tables'
		'm'
	]
	type: 'bool'
	help: 'Migrate to the latest revision.'
	action: migrateTables
]

actions = {}
options.forEach( (op) -> actions[(op.name || op.names[0]).replace(/-/g,'_')] = op.action if op.action )

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

#console.log("# opts:", opts); // debug

#
#var optimist = require('optimist');
#var argv = optimist
#	.alias('help', 'h')
#	.alias('info', 'i')
#	.alias('tables', 't')
#	.alias('unify-validate', 'l')
#	.alias('unify-export', 'u')
#	.alias('optimize', 'o')
#	.alias('optimize', 'O')
#	.alias('test-monsters', 'm')
#	.alias('drop', 'd')
#	.usage('Usage: $0 <commands>')
#	.describe('help', 'Show this text')
#	.describe('info', 'Show current revision and status')
#	.describe('tables', 'Migrate tables to the last revision')
#	.describe('unify-validate', 'Validate unify files')
#	.describe('unify-export', 'Parse unify files and push them to database')
#	.describe('optimize', 'Optimize tables')
#	.describe('test-monsters', 'Insert test monsters')
#	.describe('drop', 'Drop all tables and set revision to -1')
#	.boolean(['help','info','tables','unify-validate','unify-export','optimize','test-monsters','drop'])
#	.argv;
#
#// [--database] [--tables] [--unify-validate] [--unify-export] [--optimize] [--test-monsters] [--drop]
#
#if (argv.help === true)
# {
#	optimist.showHelp();
# }

#async.parallel [
#		(callback) ->
#			console.log(1)
#			callback(null)
#		,
#		(callback) ->
#			console.log(2)
#			callback(null)
#	],
#	(err, res) -> console.log(err, res)

if opts.help is true
	console.log "\nUsage: node init.js <commands>\n\n#{parser.help(includeEnv: true).trimRight()}"
	process.exit 2

anyDB = require 'any-db'

if opts.info is true
	mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL)
	utils.migration.getCurrentRevision mysqlConnection, (error, result) ->
		if error?
			console.log error
			process.exit 1
		else
			newest = utils.migration.getNewestRevision()
			status = if result < newest then 'needs update' else 'up to date'
			console.log "init.js with #{newest + 1} revisions on board."
			console.log "Current revision is #{result} (#{status})."
			process.exit 0

#if opts.create_database?
#	func_count = 0
#	create = (db_url) ->
#		func_count++
#		db_path = db_url.match(/.+\//)[0]
#		db_name = db_url.match(/[^\/]+$/)[0]
#		conn = anyDB.createConnection(db_path)
#		conn.query 'CREATE DATABASE ' + db_name, [], (error, result) ->
#			func_count--
#			checkError error, func_count isnt 0
#			console.log "#{db_name} created."
#			process.exit 0 if func_count is 0
#	create config.MYSQL_DATABASE_URL if opts.create_database is 'main' or opts.create_database is 'both'
#	create config.MYSQL_DATABASE_URL_TEST if opts.create_database is 'test' or opts.create_database is 'both'

i = 0
iter = () ->
	process.exit 0 if i >= opts._order.length
	op = opts._order[i]
	actions[op.key] op.value, (error) ->
		checkError error
		i++
		iter()
iter()
