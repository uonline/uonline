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


module.exports = class Account
	existsID: (id) ->  # boolean
		throw new Error 'not implemented'
	byID: (id) ->  # boolean
		throw new Error 'not implemented'
	existsName: (username) ->  # boolean
		throw new Error 'not implemented'
	byName: (username) ->  # boolean
		throw new Error 'not implemented'
	create: (account) ->
		throw new Error 'not implemented'
	accessGranted: (name, password) ->  # boolean
		throw new Error 'not implemented'
	update: (object) ->
		throw new Error 'not implemented'
	updatePassword: (id, password) ->
		throw new Error 'not implemented'
	remove: (id) ->
		throw new Error 'not implemented'
