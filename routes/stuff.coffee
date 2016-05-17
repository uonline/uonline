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
config = require "#{__dirname}/../config"
{openTransaction, commit, wrap, setInstance, render, redirect} = require "#{__dirname}/../lib/middlewares.coffee"


module.exports =
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
