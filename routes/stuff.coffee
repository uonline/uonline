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

{async, await} = require 'asyncawait'
config = require '../config'
{wrap, openTransaction, commit, setInstance, render, redirect} = require '../lib/middlewares.coffee'


module.exports =
	'/':
		get: (request, response, next) ->
			if request.uonline.user.loggedIn is true
				response.redirect 303, config.defaultInstanceForUsers
			else
				response.redirect 303, config.defaultInstanceForGuests
			next()

	'/about/':
		get: [
			setInstance('about')
			render('about')
		]

	'/state/':
		get: [
			wrap(async (request, response, next) ->
				players = await request.uonline.db.queryAsync(
					"SELECT *, (sess_time > NOW() - $1 * INTERVAL '1 SECOND') AS online FROM uniusers",
					[config.sessionExpireTime]
				)
				request.uonline.userstate = players.rows
				next()
			)
			setInstance('state')
			render('state')
		]

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

	'/ajax/cheatFixAll':
		post: wrap async (request, response) ->
			await request.uonline.db.queryAsync(
				'UPDATE items '+
				'SET strength = '+
					'(SELECT strength_max FROM items_proto'+
					' WHERE items.prototype = items_proto.id)'
			)
			response.redirect 303, '/inventory/'
