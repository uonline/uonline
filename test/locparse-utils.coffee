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

NS = 'locparse-utils'; exports[NS] = {}  # namespace
{test, t, requireCovered, config} = require '../lib/test-utils.coffee'

parser = requireCovered __dirname, '../lib/locparse.coffee'


class Log
	constructor: () ->
		@errors = []
		@warns = []
		@result = {}
	warn: (pointer, id, message) -> @warns.push pointer:pointer, id:id, message:message
	error: (pointer, id, message) -> @errors.push pointer:pointer, id:id, message:message
	all: -> @errors.concat @warns
	setFilename: ->
	testIfCorrect: (test, errsOrWarns, expected_objs, message) ->
		objs = this[errsOrWarns].slice()
		for expected in expected_objs # тут можно написать тесты для теста :|
			exists = objs.some (obj, i) ->
				for field of expected
					return false if obj[field] isnt expected[field]
				objs.splice i, 1
				return true

			unless exists
				test.deepEqual objs, expected, message


exports[NS].makeId =
	'id should fit DB int key': ->
		for i in [0..100]
			id = parser.makeId new Buffer(Math.random()+'').toString('base64')
			test.isAtLeast id, 0
			test.isAtMost id, 0x80000000


exports[NS].isAreaLabel =
	beforeEach: ->
		this.log = new Log

	'should detect correct areas': ->
		test.isTrue parser.isAreaLabel('# Area Label', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip simple lines': ->
		test.isFalse parser.isAreaLabel('Just line', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip location title': ->
		test.isFalse parser.isAreaLabel('### Location', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip sharped line with warning': ->
		test.isFalse parser.isAreaLabel('#something', 12, this.log)
		this.log.testIfCorrect test, 'warns', [pointer:12, id:'W1']
		test.deepEqual this.log.errors, []


exports[NS].isLocationLabel =
	beforeEach: ->
		this.log = new Log

	'should detect locations': ->
		test.isTrue parser.isLocationLabel('### Location', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip simple lines': ->
		test.isFalse parser.isLocationLabel('Just line', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip sharped line with warning': ->
		test.isFalse parser.isLocationLabel('###something', 5, this.log)
		this.log.testIfCorrect test, 'warns', [pointer:5, id:'W2']
		test.deepEqual this.log.errors, []


exports[NS].isListItem =
	beforeEach: ->
		this.log = new Log

	'should detect list items': ->
		test.isTrue parser.isListItem('* go somewhere', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip simple lines': ->
		test.isFalse parser.isListItem('Just line', 0, this.log)
		test.deepEqual this.log.all(), [], 'without warnings or errors'

	'should skip line with warning if no space after "*"': ->
		test.isFalse parser.isListItem('*something', 42, this.log)
		this.log.testIfCorrect test, 'warns', [pointer:42, id:'W3']
		test.deepEqual this.log.errors, []


exports[NS].isLinkLine =
	'should detect links': ->
		test.isTrue parser.isLinkLine('![The Image](/location.jpg)', 0, null)

	'should skip simple lines': ->
		test.isFalse parser.isLinkLine('Just line.', 0, null)


exports[NS].isEmpty =
	beforeEach: ->
		this.log = new Log

	'should detect empty lines': ->
		test.isTrue parser.isEmpty('', 0, this.log)
		test.deepEqual this.log.all(), []

	'should skip simple lines': ->
		test.isFalse parser.isEmpty('Just line', 0, this.log)
		test.deepEqual this.log.all(), []

	'lines of spaces should be considered empty and produce warning': ->
		test.isTrue parser.isEmpty('   ', 32, this.log)
		this.log.testIfCorrect test, 'warns', [pointer:32, id:'W4']
		test.deepEqual this.log.errors, []


exports[NS].checkSpaces =
	'should not generate errors or warnings for correct line': ->
		log = new Log
		parser.checkSpaces('Normal line', 0, log)
		test.deepEqual log.all(), []

	'should warn about spaces on each side': ->
		log = new Log
		parser.checkSpaces('   spaces all over there   ', 21, log)
		log.testIfCorrect test, 'warns', [ {pointer:21, id:'W6'}, {pointer:21, id:'W5'} ]
		test.deepEqual log.errors, []


exports[NS].checkPropUniqueness =
	beforeEach: ->
		this.log = new Log
		this.objs = [
			{a: 1}
			{a: 2, b: 1}
			{a: "qwe", b: 1}
		]

	'should not generate anything if properties are unique': ->
		parser.checkPropUniqueness this.objs, 0, 'N/a', 'a', this.log
		test.deepEqual this.log.all(), []

	'should spawn error about duplicated value': ->
		this.objs[0].a = 2
		parser.checkPropUniqueness this.objs, 8, 'N/a', 'a', this.log
		this.log.testIfCorrect test, 'errors', [pointer:8, id:'N/a']
		test.deepEqual this.log.warns, []


exports[NS].postCheck =
	"should not produce warnings or errors if everything's ok": ->
		log = new Log
		log.result.areas = [
			{ id: 1 }
			{ id: 2 }
		]
		log.result.locations = [
			{ id: 1, label: 'loc1', actions: {'loc1': "somewhere", 'loc2': "anywhere"} }
			{ id: 2, label: 'loc2' }
			{ id: 3, label: 'loc3' }
		]
		log.result.initialLocation = log.result.areas[0]
		parser.postCheck log
		test.deepEqual log.all(), []

	'should generate errors when there are integrity issues': ->
		log = new Log
		log.result.areas = [
			{ id: 1 }
			{ id: 1 }
		]
		log.result.locations = [
			{ id: 1, label: 'loc1', actions: {'loc1': "somewhere", 'noSuchLoc': "nowhere"} }
			{ id: 2, label: 'loc2' }
			{ id: 1, label: 'loc1' }
		]
		log.result.initialLocation = null
		parser.postCheck log
		log.testIfCorrect test, 'errors', [
				{id: 'E1',  pointer: 'actions'}
				{id: 'E6',  pointer: 'locations'}
				{id: 'E7',  pointer: 'locations'}
				{id: 'N/a', pointer: 'areas'}  # same id
				{id: 'N/a', pointer: 'locations'}  # same id
			]
		test.deepEqual log.warns, []
