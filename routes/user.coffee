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
mw = lib.middlewares


module.exports =
	'/login/':
		get: [
			mw.mustNotBeAuthed
			mw.setInstance('login')
			mw.render('login')
		]

	'/action/login':
		post: [
			mw.mustNotBeAuthed
			mw.setInstance('login')
			mw.wrap async (request, response) ->
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
			mw.mustBeAuthed
			mw.wrap async (request, response) ->
				await lib.user.closeSession request.uonline.db, request.uonline.user.sessid
				response.redirect 303, config.defaultInstanceForGuests  # force GET
		]

	'/register/':
		get: [
			mw.mustNotBeAuthed
			mw.setInstance('register')
			mw.render('register')
		]

	'/action/register':
		post: [
			mw.mustNotBeAuthed
			mw.setInstance('register')
			mw.openTransaction
			mw.wrap async (request, response) ->
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
		get: mw.wrap async (request, response) ->
			response.json
				nick: request.params.nick
				isNickBusy: await lib.user.userExists request.uonline.db, request.params.nick

	'/account/':
		get: [
			mw.mustBeAuthed
			mw.setInstance('account')
			(request, response) ->
				response.render 'account', request.uonline
		]
