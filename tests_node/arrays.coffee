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


require '../lib-cov/arrays'


exports.pickRandom = (test) ->
	arr = [1..5]
	set = {}
	set[arr.pickRandom()] = 1 for [1..100]
	
	test.ok(x of set, 'each random element should be from array') for x in arr
	test.strictEqual arr.length, Object.keys(set).length, 'all array elements should have chance to be picked'
	
	test.strictEqual null, [].pickRandom()
	test.done()
