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

strings = require '../lib-cov/strings'

exports.startsWith = (test) ->
	test.strictEqual true, 'abcd'.startsWith('a')
	test.strictEqual true, 'abcd'.startsWith('abc')
	test.strictEqual true, 'abcd'.startsWith('abcd')
	test.strictEqual false, 'abcd'.startsWith('abcdd')
	test.strictEqual false, 'abcd'.startsWith('bc')
	test.strictEqual true, 'abcd'.startsWith('')
	test.done()

exports.endsWith = (test) ->
	test.strictEqual true, 'abcd'.endsWith('d')
	test.strictEqual true, 'abcd'.endsWith('bcd')
	test.strictEqual true, 'abcd'.endsWith('abcd')
	test.strictEqual false, 'abcd'.endsWith('abcdd')
	test.strictEqual false, 'abcd'.endsWith('bc')
	test.strictEqual true, 'abcd'.endsWith('')
	test.done()
