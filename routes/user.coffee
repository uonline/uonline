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
lib = require '../lib.coffee'
{wrap, openTransaction, setInstance, render, mustNotBeAuthed, mustBeAuthed} = lib.middlewares


module.exports =
	'/login/':
		get: [
			mustNotBeAuthed
			setInstance('login')
			render('login')
		]

	'/action/login':
		post: [
			mustNotBeAuthed
			setInstance('login')
			wrap async (request, response) ->
				if await lib.user.accessGranted request.uonline.db, request.body.username, request.body.password
					sessid = await lib.user.createSession request.uonline.db, request.body.username
					response.cookie 'sessid', sessid
					response.redirect 303, config.defaultInstanceForUsers
				else
					options = request.uonline
					options.error = true
					options.user.username = request.body.username
					response.render 'login', options
		]

	'/action/logout':
		post: [
			mustBeAuthed
			wrap async (request, response) ->
				await lib.user.closeSession request.uonline.db, request.uonline.user.sessid
				response.redirect 303, config.defaultInstanceForGuests  # force GET
		]

	'/register/':
		get: [
			mustNotBeAuthed
			setInstance('register')
			render('register')
		]

	'/action/register':
		post: [
			mustNotBeAuthed
			setInstance('register')
			openTransaction
			wrap async (request, response) ->
				usernameIsValid = lib.validation.usernameIsValid(request.body.username)
				passwordIsValid = lib.validation.passwordIsValid(request.body.password)
				userExists = await lib.user.userExists request.uonline.db, request.body.username

				if usernameIsValid and passwordIsValid and !userExists
					result = await lib.user.registerUser(
						request.uonline.db
						request.body.username
						request.body.password
						'user'
					)
					await request.uonline.db.commitAsync()
					response.cookie 'sessid', result.sessid
					response.redirect 303, '/account/'
				else
					options = request.uonline
					options.error = true
					options.invalidLogin = !usernameIsValid
					options.invalidPass = !passwordIsValid
					options.loginIsBusy = userExists
					options.user.username = request.body.username
					options.user.password = request.body.password
					await request.uonline.db.rollbackAsync()
					response.render 'register', request.uonline
		]

	'/ajax/isNickBusy/:nick':
		get: wrap async (request, response) ->
			response.json
				nick: request.params.nick
				isNickBusy: await lib.user.userExists request.uonline.db, request.params.nick

	'/account/':
		get: [
			mustBeAuthed
			setInstance('account')
			(request, response) ->
				response.render 'account', request.uonline
		]
