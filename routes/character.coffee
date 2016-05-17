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
mw = require "#{__dirname}/../lib/middlewares.coffee"


module.exports =
	'/character/':
		get: [
			mw.mustBeAuthed
			mw.mustHaveCharacter
			mw.setInstance('mycharacter')
			(request, response) ->
				#request.uonline.fetched_character_owner = request.uonline.user  # пока не вижу смысла его запрашивать
				request.uonline.fetched_character = request.uonline.character
				response.render 'character', request.uonline
		]

	'/character/:name/':
		get: [
			mw.mustBeAuthed
			mw.fetchCharacterFromURL
			mw.setInstance('character')
			(request, response) ->
				#console.log(require('util').inspect(request.uonline, depth: null))
				response.render 'character', request.uonline
		]

	'/newCharacter/':
		get: [
			mw.mustBeAuthed
			mw.setInstance('new_character')
			(request, response) ->
				response.render 'new_character', request.uonline
		]

	'/action/newCharacter':
		post: [
			mw.mustBeAuthed
			mw.setInstance('new_character')
			mw.openTransaction
			mw.wrap async (request, response, next) ->
				nameIsValid = lib.validation.characterNameIsValid(request.body.character_name)
				alreadyExists = await lib.character.characterExists request.uonline.db, request.body.character_name

				if nameIsValid and not alreadyExists
					charid = await lib.character.createCharacter(
						request.uonline.db
						request.uonline.user.id
						request.body.character_name
						request.body.character_race
						request.body.character_gender
					)
					await request.uonline.db.commitAsync()
					response.redirect 303, '/character/'
				else
					options = request.uonline
					options.error = true
					options.invalidName = !nameIsValid
					options.nameIsBusy = alreadyExists
					options.character_name = request.body.character_name
					await request.uonline.db.rollbackAsync()
					response.render 'new_character', request.uonline
		]

	'/action/switchCharacter':
		post: [
			mw.mustBeAuthed
			mw.wrap async (request, response) ->
				await lib.character.switchCharacter request.uonline.db, request.uonline.user.id, request.body.id
				response.redirect 303, 'back'
		]


	'/action/deleteCharacter':
		post: [
			mw.mustBeAuthed
			mw.wrap async (request, response) ->
				await lib.character.deleteCharacter request.uonline.db, request.uonline.user.id, request.body.id
				response.redirect 303, '/account/'
		]
