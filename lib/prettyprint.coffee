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

offset = 0

exports.spaces = (count) ->
	s = ''
	i = 0
	while i < count
		s += ' '
		i++
	s

exports.writeln = (text, targetFunction = console.log) ->
	targetFunction @spaces(offset) + text
	return

exports.section = (name, targetFunction = console.log) ->
	@writeln name + '...', targetFunction
	offset += 2
	offset

exports.endSection = ->
	offset -= 2
	offset

exports.action = (name, targetFunction = process.stdout.write) ->
	targetFunction @spaces(offset) + name + '...'
	return

exports.result = (result, targetFunction = console.log) ->
	targetFunction ' ' + result
	return
