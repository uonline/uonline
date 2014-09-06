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


require '../lib-cov/numbers'


exports.random = (test) ->
	for x in [0..1000]
		r = Number.random(-10, 10)
		test.ok(-10<=r and r<10, "should return random value between two numbers if both are passed")
	
	for x in [0..1000]
		r = Number.random(10)
		test.ok(0<=r and r<10, "should return random value between 0 and passed number in case of one argument")
	
	test.notStrictEqual(Number.random(10), Number.random(10), "should return different values")
	test.done()


exports.irandom = (test) ->
	for x in [0..1000]
		r = Number.irandom(-10, 10)
		test.ok(-10<=r and r<10, "should return random value between two numbers if both are passed")
		test.strictEqual(r, Math.round(r), "should return integer value if both arguments are passed")
	
	for x in [0..1000]
		r = Number.irandom(10)
		test.ok(0<=r and r<10, "should return random value between 0 and passed number in case of one argument")
		test.strictEqual(r, Math.round(r), "should return integer value if one argument is passed")
	
	hit_left = false
	for x in [0..1000]
		if Number.irandom(-10, 10) == -10
			hit_left = true
			break
	test.ok(hit_left, "should sometimes hiy left border")
	
	test.notStrictEqual(Number.irandom(1000), Number.irandom(1000), "should return different values")
	test.done()
