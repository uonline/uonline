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

async = require 'async'


exports.tableExists = (dbConnection, name, callback) ->
	dbConnection.query 'SELECT count(*) AS result FROM information_schema.tables WHERE table_name = $1',
		[ name ], (error, result) ->
			callback error, error or result.rows[0].result > 0
	return

exports.create = (dbConnection, table, data, callback) ->
	dbConnection.query "CREATE TABLE #{table} (#{data})", (error, result) ->
		callback error, error or true
	return

exports.addCol = (dbConnection, table, column, callback) ->
	dbConnection.query "ALTER TABLE #{table} ADD COLUMN #{column}", (error, result) ->
		callback error, error or true
	return

exports.renameCol = (dbConnection, table, colOld, colNew, callback) ->
	#ALTER TABLE employee RENAME COLUMN start_date TO hire_date;
	dbConnection.query "ALTER TABLE #{table} RENAME COLUMN #{colOld} TO #{colNew}", (error, results) ->
		callback error, error or true
	return

exports.changeCol = (dbConnection, table, colName, colAttrs, callback) ->
	dbConnection.query "ALTER TABLE #{table} ALTER COLUMN #{colName} TYPE #{colAttrs}", callback
	return

exports.changeDefault = (dbConnection, table, colName, value, callback) ->
	dbConnection.query "ALTER TABLE #{table} ALTER COLUMN #{colName} SET DEFAULT #{value}", callback
	return

exports.dropCol = (dbConnection, table, column, callback) ->
	dbConnection.query "ALTER TABLE #{table} DROP COLUMN #{column}", (error, result) ->
		callback error, error or true
	return

exports.createIndex = (dbConnection, table, column, callback) ->
	dbConnection.query "CREATE INDEX #{table}_#{column} ON #{table} (#{column})", (error, result) ->
		callback error, error or true
	return

exports.createEnum = (dbConnection, enumName, values, callback) ->
	dbConnection.query "CREATE TYPE #{enumName} AS ENUM (#{values})", (error, result) ->
		callback error, error or true
	return

