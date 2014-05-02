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


# Check if a string starts with a given substring.
# @return [Boolean]
String::startsWith = (x) ->
	if x.length > this.length
		return false
	return this.substring(0,x.length) == x


# Check if a string ends with a given substring.
# @return [Boolean]
String::endsWith = (x) ->
	if x.length > this.length
		return false
	return this.substring(this.length-x.length, this.length) == x
