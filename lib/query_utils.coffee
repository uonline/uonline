sync = require 'sync'

exports.getFor = (dbConnection) ->
	func = (sql, params) ->
		dbConnection.query.sync(dbConnection, sql, params).rows
		return
	
	func.all = (sql, params) ->
		dbConnection.query.sync(dbConnection, sql, params).rows
	
	func.row = (sql, params) ->
		rows = @all sql, params
		if rows.length isnt 1
			throw new Error('In query:\n#{sql}\nExpected one row, but got #{rows.length}')
		rows[0]
	
	func.val = (sql, params) ->
		row = @row sql, params
		keys = Object.keys row
		if keys.length isnt 1
			throw new Error('In query:\n#{sql}\nExpected one value, but got #{keys.length} (#{keys.join(", ")})')
		row[keys[0]]
	
	func
