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
lib = require '../lib.coffee'
mw = lib.middlewares


module.exports =
	'/monster/:id/':
		get: [
			mw.fetchMonsterFromURL
			mw.setInstance('monster')
			mw.render('monster')
		]

	'/game/':
		get: [
			mw.mustBeAuthed,
			mw.mustHaveCharacter,
			mw.fetchLocation, mw.fetchArea,
			mw.fetchUsersNearby, mw.fetchMonstersNearby,
			mw.fetchBattleGroups, mw.fetchItems,
			mw.setInstance('game'), mw.render('game')
		]

	'/inventory/':
		get: [
			mw.mustBeAuthed, mw.mustHaveCharacter, mw.fetchItems,
			mw.setInstance('inventory'), mw.render('inventory')
		]

	'/action/go':
		post: [
			mw.mustBeAuthed
			mw.openTransaction
			async((request, response) ->
				result = await lib.game.changeLocation request.uonline.db,
					request.uonline.user.character_id, request.body.to
				if result.result != 'ok'
					console.error "Location change failed: #{result.reason}"
			)
			mw.commit
			mw.redirect(303, '/game/')
		]

	'/action/attack':
		post: [
			mw.mustBeAuthed
			mw.openTransaction
			async (request, response) ->
				await lib.game.goAttack request.uonline.db, request.uonline.user.character_id
			mw.commit
			mw.redirect(303, '/game/')
		]

	'/action/escape':
		post: [
			mw.mustBeAuthed
			mw.openTransaction
			async (request, response) ->
				await lib.game.goEscape request.uonline.db, request.uonline.user.character_id
			mw.commit
			mw.redirect(303, '/game/')
		]

	'/action/hit':
		post: [
			mw.mustBeAuthed
			mw.openTransaction
			async (request, response) ->
				await lib.game.hitOpponent(
					request.uonline.db,
					request.uonline.user.character_id,
					request.body.id,
					request.body.with_item_id
				)
			mw.commit
			mw.redirect(303, '/game/')
		]

	'/action/unequip':
		post: [
			mw.mustBeAuthed
			async (request, response) ->
				await request.uonline.db.queryAsync(
					'UPDATE items SET equipped = false WHERE id = $1 AND owner = $2',
					[request.body.id, request.uonline.user.character_id]
				)
				response.redirect 303, '/inventory/'
		]

	'/action/equip':
		post: [
			mw.mustBeAuthed
			async (request, response) ->
				await request.uonline.db.queryAsync(
					'UPDATE items SET equipped = true WHERE id = $1 AND owner = $2',
					[request.body.id, request.uonline.user.character_id]
				)
				response.redirect 303, '/inventory/'
		]
