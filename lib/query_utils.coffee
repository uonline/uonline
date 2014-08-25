sync = require 'sync'

exports.getFor = (dbConnection) ->
	query = (sql, params) ->
		dbConnection.query.sync dbConnection, sql, params
	
	query.all = (sql, params) ->
		dbConnection.query.sync(dbConnection, sql, params).rows
	
	query.row = (sql, params) ->
		rows = @all sql, params
		if rows.length isnt 1
			throw new Error('In query:\n#{sql}\nExpected one row, but got #{rows.length}')
		rows[0]
	
	query.val = (sql, params) ->
		row = @row sql, params
		keys = Object.keys row
		if keys.length isnt 1
			throw new Error('In query:\n#{sql}\nExpected one value, but got #{keys.length} (#{keys.join(", ")})')
		row[keys[0]]
	
	query.ins = (dbName, fields) ->
		params = []
		values = []
		for i of fields
			params.push i
			values.push (if typeof fields[i] is 'string' then "'#{fields[i]}'" else fields[i])
		query "INSERT INTO #{dbName} (#{params.join(', ')}) VALUES (#{values.join(', ')})"
	
	query
