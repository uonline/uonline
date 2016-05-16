'use strict'


{async, await} = require 'asyncawait'
config = require "#{__dirname}/../config"
{openTransaction, commit, wrap, setInstance, render, redirect} = require "#{__dirname}/../lib/middlewares.coffee"


_exports =
	'/node/':
		get: (request, response) ->
			response.send 'Node.js is up and running.'

	'/explode/':
		get: (request, response) ->
			throw new Error 'Emulated error.'

	'/explode_db/':
		get: [
			openTransaction
			wrap(async (request, response) ->
				await request.uonline.db.queryAsync 'SELECT * FROM "Emulated DB error."'
			)
			commit
		]

	'/':
		get: (request, response) ->
			if request.uonline.user.loggedIn is true
				response.redirect config.defaultInstanceForUsers
			else
				response.redirect config.defaultInstanceForGuests

	'/about/':
		get: [
			setInstance('about')
			render('about')
		]


for i of _exports
	exports[i] = _exports[i]
