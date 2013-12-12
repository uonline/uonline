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

checkArgs = (passed, available) ->
	unless passed in available
		console.log "Unknown argument: #{passed}"
		console.log "Available: #{available}"
		process.exit 1

config = require './config.js'
utils = require './utils.js'
async = require 'async'
dashdash = require 'dashdash'

anyDB = null
needAnyDB = () ->
	anyDB = require 'any-db' unless anyDB?


help = (arg, callback) ->
	console.log "\nUsage: node init.js <commands>\n\n#{parser.help(includeEnv: true).trimRight()}"
	process.exit 2

info = (arg, callback) ->
	needAnyDB()
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

createDatabase = (arg, callback) ->
	needAnyDB()
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
	funcs.push((callback) -> create config.MYSQL_DATABASE_URL, callback) if arg in ['main', 'both']
	funcs.push((callback) -> create config.MYSQL_DATABASE_URL_TEST, callback) if arg in ['test', 'both']

	async.parallel funcs, callback


dropDatabase = (arg, callback) ->
	needAnyDB()
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
	funcs.push((callback) -> drop config.MYSQL_DATABASE_URL, callback) if arg in ['main', 'both']
	funcs.push((callback) -> drop config.MYSQL_DATABASE_URL_TEST, callback) if arg in ['test', 'both']

	async.parallel funcs, callback


migrateTables = (arg, callback) ->
	needAnyDB()
	mysqlConnection = anyDB.createConnection(config.MYSQL_DATABASE_URL)
	utils.migration.migrate mysqlConnection, callback


options = [
	names: [
		'help'
		'h'
	]
	type: 'bool'
	help: 'Print this help and exit.'
	action: help
,
	names: [
		'info'
		'i'
	]
	type: 'bool'
	help: 'Show current revision and status.'
	action: info
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

funcs = []
opts._order.forEach (op) -> funcs.push( (callback) -> actions[op.key] op.value, callback )
async.series funcs, (error) ->
	checkError error
	process.exit 0
