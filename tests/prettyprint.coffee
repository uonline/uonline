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

prettyprint = require '../lib/prettyprint'


exports.spaces = (test) ->
	test.strictEqual prettyprint.spaces(0), '', 'should return empty string when I ask for 0 spaces'
	test.strictEqual prettyprint.spaces(1), ' ', 'should return given number of spaces'
	test.strictEqual prettyprint.spaces(4), '    ', 'should return given number of spaces'
	test.done()


exports.writeln = (test) ->
	test.expect 1
	targetFunction = (text) ->
		test.strictEqual text, "Nikolai Baskov is up and running.", "should print text"
	prettyprint.writeln "Nikolai Baskov is up and running.", targetFunction
	test.done()


exports.section = (test) ->
	test.expect 4

	targetFunction = undefined
	result = undefined

	targetFunction = (text) ->
		test.strictEqual text, "Killing...", "should print text without offset at first call"
	result = prettyprint.section("Killing", targetFunction)
	test.strictEqual result, 2, "should increase offset by 2 every time"

	targetFunction = (text) ->
		test.strictEqual text, "  Killing...", "should print text with offset"
	result = prettyprint.section("Killing", targetFunction)
	test.strictEqual result, 4, "should increase offset by 2 every time"

	prettyprint.endSection()
	prettyprint.endSection()

	test.done()


exports.endSection = (test) ->
	targetFunction = undefined
	result = undefined
	targetFunction = (text) -> # do nothing

	result = prettyprint.section("some section", targetFunction)
	result = prettyprint.section("some section", targetFunction)
	result = prettyprint.endSection()
	test.strictEqual result, 2, "should decrease offset by 2"
	result = prettyprint.endSection()
	test.strictEqual result, 0, "should decrease offset by 2"
	test.done()


exports.action = (test) ->
	test.expect 3
	targetFunction = undefined
	result = undefined

	targetFunction = (text) ->
		test.strictEqual text, "Killing...", "should print text with section offset"
	prettyprint.action "Killing", targetFunction

	targetFunction = (text) -> # do nothing
	prettyprint.section "some section", targetFunction
	targetFunction = (text) ->
		test.strictEqual text, "  Killing...", "should print text with section offset"
	prettyprint.action "Killing", targetFunction
	prettyprint.endSection()

	targetFunction = (text) ->
		test.strictEqual text, "Killing...", "should print text with section offset"
	prettyprint.action "Killing", targetFunction

	test.done()


exports.result = (test) ->
	test.expect 1
	targetFunction = undefined
	result = undefined

	targetFunction = (text) ->
		test.strictEqual text, " done", "should print text with one-space offset"
	prettyprint.result "done", targetFunction
	test.done()
