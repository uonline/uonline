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


# Returns random number between a and b
# or a and 0 if b is undefined
# TODO: #394 ?
Number.random = (a, b) ->
	b = 0 unless b?
	a + Math.random() * (b - a)

# As Number::random but with only ints
Number.irandom = (a, b) ->
	Math.floor(Number.random(a, b))
