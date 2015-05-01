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


exports.makeId_test = (test) ->
	for i in [0..100]
		id = parser.makeId new Buffer(Math.random()+'').toString('base64')
		test.ok id >= 0 and id < 0x80000000, 'id should fit DB int key'
	test.done()


exports.isAreaLabel_test = (test) ->
	log = new Log

	test.ok parser.isAreaLabel('# Area Label', 0, log), 'should detect correct areas'
	test.deepEqual log.all(), {}, 'correct label should not cause warnings or errors'

	test.ok !parser.isAreaLabel('Just line', 0, log), 'should skip simple lines'
	test.deepEqual log.all(), {}, 'simple line should not cause warnings or errors'

	test.ok !parser.isAreaLabel('### Location', 0, log), 'should skip location title'
	test.deepEqual log.all(), {}, 'location title should not cause warnings or errors'

	test.ok !parser.isAreaLabel('#something', 12, log), 'should skip sharped line too'
	log.testIfCorrect test, 'warns', [pointer:12, id:'W1'], 'should warn about sharped line'
	test.deepEqual log.errors, {}, 'should not produce errors on sharped line'

	test.done()


exports.isLocationLabel_test = (test) ->
	log = new Log

	test.ok parser.isLocationLabel('### Location', 0, log), 'should detect locations'
	test.deepEqual log.all(), {}, 'correct label should not cause warnings or errors'

	test.ok !parser.isLocationLabel('Just line', 0, log), 'should skip simple lines'
	test.deepEqual log.all(), {}, 'simple line should not cause warnings or errors'

	test.ok !parser.isLocationLabel('###something', 5, log), 'should skip sharped line too'
	log.testIfCorrect test, 'warns', [pointer:5, id:'W2'], 'should warn about sharped line'
	test.deepEqual log.errors, {}, 'should not produce errors on sharped line'

	test.done()


exports.isListItem_test = (test) ->
	log = new Log

	test.ok parser.isListItem('* go somewhere', 0, log), 'should detect list items'
	test.deepEqual log.all(), {}, 'correct item should not cause warnings or errors'

	test.ok !parser.isListItem('Just line', 0, log), 'should skip simple lines'
	test.deepEqual log.all(), {}, 'simple line should not cause warnings or errors'

	test.ok !parser.isListItem('*something', 42, log), 'should skip line if no space after "*"'
	log.testIfCorrect test, 'warns', [pointer:42, id:'W3'], 'should warn about "*" without space'
	test.deepEqual log.errors, {}, 'should not produce errors on "*" without space'

	test.done()


exports.isLinkLine = (test) ->
	test.ok parser.isLinkLine('![The Image](/location.jpg)', 0, null), 'should detect link'
	test.ok !parser.isLinkLine('Just line.', 0, null), 'should skip simple lines'
	test.done()


exports.isEmpty_test = (test) ->
	log = new Log

	test.ok parser.isEmpty('', 0, log), 'should detect empty lines'
	test.deepEqual log.all(), {}, 'empty line should not cause warnings or errors'

	test.ok !parser.isEmpty('Just line', 0, log), 'should skip simple lines'
	test.deepEqual log.all(), {}, 'simple line should not cause warnings or errors'

	test.ok parser.isEmpty('   ', 32, log), 'lines of spaces should be considered empty'
	log.testIfCorrect test, 'warns', [pointer:32, id:'W4'], 'should warn about line of spaces'
	test.deepEqual log.errors, {}, 'should not produce errors on line of spaces'

	test.done()


exports.checkSpaces_test = (test) ->
	log = new Log

	parser.checkSpaces('Normal line', 0, log)
	test.deepEqual log.all(), {}, 'should not generate anything for correct line'

	parser.checkSpaces('   spaces all over there   ', 21, log)
	log.testIfCorrect test, 'warns',
		[ {pointer:21, id:'W6'}, {pointer:21, id:'W5'} ],
		'should warn about spaces on each side'
	test.deepEqual log.errors, {}, 'should not produce errors'

	test.done()


exports.checkPropUniqueness_test = (test) ->
	log = new Log
	objs = [
		a: 1
	,
		a: 2
		b: 1
	,
		a: "qwe"
		b: 1
	]
	parser.checkPropUniqueness objs, 0, 'N/a', 'a', log
	test.deepEqual log.all(), {}, 'should not generate anything if properties are unique'

	objs[0].a = 2
	parser.checkPropUniqueness objs, 8, 'N/a', 'a', log
	log.testIfCorrect test, 'errors', [pointer:8, id:'N/a'], 'should spawn error about duplicated value'
	test.deepEqual log.warns, {}, 'should not produce warnings'

	test.done()


exports.postCheck_test =
	'correct': (test) ->
		log = new Log
		log.result.areas = [
			{ id: 1 }
			{ id: 2 }
		]
		log.result.locations = [
			id: 1
			label: 'loc1'
			actions:
				'loc1': "somewhere"
				'loc2': "anywhere"
		,
			id: 2
			label: 'loc2'
		,
			id: 3
			label: 'loc3'
		]
		log.result.initialLocation = log.result.areas[0]
		parser.postCheck log
		test.deepEqual log.all(), {}, "should not produce warnings or errors if everything's ok"
		test.done()

	'errors': (test) ->
		log = new Log
		log.result.areas = [
			{ id: 1 }
			{ id: 1 }
		]
		log.result.locations = [
			id: 1
			label: 'loc1'
			actions:
				'loc1': "somewhere"
				'noSuchLoc': "nowhere"
		,
			id: 2
			label: 'loc2'
		,
			id: 1
			label: 'loc1'
		]
		log.result.initialLocation = null
		parser.postCheck log
		log.testIfCorrect test, 'errors', [
				{id: 'E1',  pointer: 'actions'}
				{id: 'E6',  pointer: 'locations'}
				{id: 'E7',  pointer: 'locations'}
				{id: 'N/a', pointer: 'areas'}  # same id
				{id: 'N/a', pointer: 'locations'}  # same id
			], 'should generate errors when there are integrity issues'
		test.deepEqual log.warns, {}, 'should not produce any warnings at all'
		test.done()

