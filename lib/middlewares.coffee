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
{async, await} = require 'asyncawait'
promisifyAll = require('bluebird').promisifyAll


asyncMiddleware = (func) ->
	return (req, res, next) ->
		func(req, res).then((-> next()), next)

exports.asyncMiddleware = asyncMiddleware


exports.wrap = (func) ->
	(req, res, next) ->
		func(req, res).then((-> next()), next)


exports.setInstance = (x) ->
	(request, response, next) ->
		request.uonline.instance = x
		next()


exports.render = (template) ->
	(request, response, next) ->
		response.render template, request.uonline
		next()


exports.redirect = (code, url) ->
	(request, response) ->
		response.redirect(code, url)


exports.openTransaction = (request, response, next) ->
	request.uonline.db = promisifyAll transaction(request.uonline.db)
	next()


exports.commit = asyncMiddleware async (request, response) ->
	await request.uonline.db.commitAsync()


exports.mustNotBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		response.redirect 303, config.defaultInstanceForUsers
	else
		next()


exports.mustBeAuthed = (request, response, next) ->
	if request.uonline.user.loggedIn is true
		next()
	else
		response.redirect 303, '/login/'


exports.mustHaveCharacter = (request, response, next) ->
	if request.uonline.character
		next()
	else
		response.redirect 303, '/account/'


exports.fetchCharacter = asyncMiddleware async (request, response) ->
	character = await lib.game.getCharacter request.uonline.db, request.uonline.user.character_id
	request.uonline.character = character


exports.fetchCharacterFromURL = asyncMiddleware async (request, response) ->
	request.uonline.fetched_character = await lib.game.getCharacter request.uonline.db, request.params.name
