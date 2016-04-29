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


transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
promisifyAll = require("bluebird").promisifyAll


exports.getFor = (db) ->
	query = (sql, params) ->
		return db.queryAsync sql, params
	
	query.all = async (sql, params) ->
		(await db.queryAsync sql, params).rows
	
	query.row = async (sql, params) ->
		rows = await @all sql, params
		if rows.length isnt 1
			throw new Error("In query:\n#{sql}\nExpected one row, but got #{rows.length}")
		rows[0]
	
	query.val = async (sql, params) ->
		row = await @row sql, params
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
exports.doInTransaction = async (db, func) ->
	tx = promisifyAll transaction(db, {autoRollback: false})
	try
		await func(tx)
	catch ex
		if tx.state() isnt 'closed'
			await tx.rollbackAsync()
		throw ex
	if tx.state() isnt 'closed'
		await tx.commitAsync()


# Inserts row to `table` with values from `fields`.
# If value is object and not Date, it will be insert as json.
exports.unsafeInsert = (db, table, fields) ->
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

	db.queryAsync "INSERT INTO #{table} (#{names}) VALUES (#{formats})", values
