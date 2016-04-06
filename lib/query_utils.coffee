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

exports.getFor = (dbConnection) ->
	query = (sql, params) ->
		dbConnection.query.sync dbConnection, sql, params
	
	query.all = (sql, params) ->
		dbConnection.query.sync(dbConnection, sql, params).rows
	
	query.row = (sql, params) ->
		rows = @all sql, params
		if rows.length isnt 1
			throw new Error("In query:\n#{sql}\nExpected one row, but got #{rows.length}")
		rows[0]
	
	query.val = (sql, params) ->
		row = @row sql, params
		keys = Object.keys row
		if keys.length isnt 1
			throw new Error("In query:\n#{sql}\nExpected one value, but got #{keys.length} (#{keys.join(', ')})")
		row[keys[0]]
	
	query.ins = (dbName, fields) ->
		params = []
		values = []
		for i of fields
			params.push i
			values.push (if typeof fields[i] is 'string' then "'#{fields[i]}'" else fields[i])
		query "INSERT INTO #{dbName} (#{params.join(', ')}) VALUES (#{values.join(', ')})"
	
	query


# Executes function passing a transaction as a first argument.
# Rollbacks transaction if any error was thrown from passed function.
exports.doInTransaction = (dbConnection, func) ->
	tx = transaction(dbConnection, {autoRollback: false})
	try
		func(tx)
	catch e
		if tx.state() isnt 'closed'
			tx.rollback.sync(tx)
		throw e
	if tx.state() isnt 'closed'
		tx.commit.sync(tx)


exports.unsafeInsert = (dbConnection, table, fields) ->
	names = []
	formats = []
	values = []

	for name, value of fields
		format = '$' + (names.length+1)
		if value? and typeof value is 'object' and !(value instanceof Date)
			format += '::json'
			value = JSON.stringify(value)
		names.push name
		formats.push format
		values.push value

	dbConnection.query.sync dbConnection, "INSERT INTO #{table} (#{names}) VALUES (#{formats})", values
