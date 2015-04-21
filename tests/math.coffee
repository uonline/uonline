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

requireCovered = require '../require-covered.coffee'
math = requireCovered __dirname, '../lib/math.coffee'

exports.ap = (test) ->
	test.strictEqual math.ap(1,2,3), 5, 'should return n-th number in arithmetical progression'
	test.strictEqual math.ap(3,6,9), 153, 'should return n-th number in arithmetical progression'
	test.done()
