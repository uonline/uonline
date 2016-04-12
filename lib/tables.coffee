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

async = require 'asyncawait/async'
await = require 'asyncawait/await'


exports.tableExists = async (db, name) ->
	result = await db.queryAsync(
		'SELECT count(*) AS result FROM information_schema.tables WHERE table_name = $1', [ name ])
	return result.rows[0].result > 0

exports.create = async (db, table, data) ->
	await db.queryAsync "CREATE TABLE #{table} (#{data})"
	return true

exports.addCol = async (db, table, column) ->
	await db.queryAsync "ALTER TABLE #{table} ADD COLUMN #{column}"
	return true

exports.renameCol = async (db, table, colOld, colNew) ->
	#ALTER TABLE employee RENAME COLUMN start_date TO hire_date;
	await db.queryAsync "ALTER TABLE #{table} RENAME COLUMN #{colOld} TO #{colNew}"
	return true

exports.changeCol = async (db, table, colName, colAttrs) ->
	await db.queryAsync "ALTER TABLE #{table} ALTER COLUMN #{colName} TYPE #{colAttrs}"
	return true

exports.changeDefault = async (db, table, colName, value) ->
	await db.queryAsync "ALTER TABLE #{table} ALTER COLUMN #{colName} SET DEFAULT #{value}"
	return true

exports.dropCol = async (db, table, columns...) ->
	drop = columns.map((col) -> "DROP COLUMN #{col}").join(', ')
	await db.queryAsync "ALTER TABLE #{table} #{drop}"
	return true

exports.createIndex = async (db, table, column) ->
	await db.queryAsync "CREATE INDEX #{table}_#{column} ON #{table} (#{column})"
	return true

exports.createEnum = async (db, enumName, values) ->
	await db.queryAsync "CREATE TYPE #{enumName} AS ENUM (#{values})"
	return true

