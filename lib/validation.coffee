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

exports.usernameIsValid = (nick) ->
	!!nick and /^[a-zA-Z0-9а-яА-ЯёЁ][a-zA-Z0-9а-яА-ЯёЁ -]{0,30}[a-zA-Z0-9а-яА-ЯёЁ]$/.test(nick)

exports.emailIsValid = (email) ->
	!!email and /^([a-z0-9_\.\-]{1,20})@([a-z0-9\.\-]{1,20})\.([a-z]{2,4})$/i.test(email)

exports.passwordIsValid = (pass) ->
	!!pass and /^[-!@#$%^&*()_+A-Za-z0-9 ]{4,32}$/.test(pass)

