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

fs = require 'fs'
parser = require '../lib-cov/locparse'
anyDB = require 'any-db'
mg = require '../lib/migration'
config = require '../config.js'
rmrf = require 'rmrf'
copy = require('ncp').ncp
copy.limit = 16 #concurrency limit
TMP_DIR = 'tests/loctests_tmp'

krontShouldBeLike =
	id: 0
	name: 'Кронт'
	label: 'kront'
	description: 'Большой и ленивый город.\nЗдесь убивают слоников и разыгрывают туристов.'
	locations: [
		id: 0
		area: null
		name: 'Другая голубая улица'
		label: 'kront/bluestreet'
		picture: null
		description: 'Здесь стоят гомосеки и немного пидарасов.'
		actions:
			'kront-outer/greenstreet': 'Пойти на Зелёную улицу'
			'kront-outer/bluestreet': 'Пойти на Голубую улицу'
	]

outerShouldBeLike =
	id: 0
	name: 'Окрестности Кронта'
	label: 'kront-outer'
	description: 'Здесь темно.'
	locations: [
		id: 0
		area: null
		name: 'Голубая улица'
		label: 'kront-outer/bluestreet'
		picture: null
		description: 'Здесь сидят гомосеки.'
		actions:
			'kront-outer/greenstreet': 'Пойти на Зелёную улицу'
	,
		id: 0
		area: null
		name: 'Зелёная улица'
		label: 'kront-outer/greenstreet'
		picture: 'животноводство.png'
		description: 'Здесь посажены деревья.\nИ грибы.\nИ животноводство.'
		actions:
			'kront/bluestreet': 'Пойти на Голубую улицу'
			'kront-outer/bluestreet': 'Пойти на другую Голубую улицу'
	]


sed = (pairs, file) ->
	data = fs.readFileSync(file, 'utf-8')
	for pair in pairs
		[oldStr, newStr] = pair
		data = data.replace(oldStr, newStr)
	fs.writeFileSync file, data, 'utf-8'


exports.setUp = (done) ->
	rmrf TMP_DIR if fs.existsSync TMP_DIR
	copy 'tests/loctests', TMP_DIR, (error) ->
		throw error if error?
		done()


exports.tearDown = (done) ->
	rmrf TMP_DIR if fs.existsSync TMP_DIR
	done()


commonTest = (test, result) ->
	test.strictEqual result.areas.length, 2, 'all areas should have been parsed'
	test.strictEqual result.locations.length, 3, 'all locations should have been parsed'

	[first, second] = result.areas

	for obj in result.areas.concat result.locations
		test.ok(obj.id >= 0 and obj.id < 0x80000000, 'id should fit DB int key')
		obj.id = 0

	for area in result.areas
		for loc in area.locations
			test.strictEqual area, loc.area, 'locations should have references to their areas'
			loc.area = null

	test.deepEqual krontShouldBeLike, first, 'area should have been parsed correctly (1)'
	test.deepEqual outerShouldBeLike, second, 'area should have been parsed correctly (2)'


exports.correct_test = (test) ->
	result = parser.processDir 'tests/loctests/Кронт - kront' #'unify/Кронт - kront'

	test.deepEqual result.warnings, [], 'should receive no warnings'
	test.deepEqual result.errors, [], 'should receive no errors'
	commonTest test, result

	test.done()


exports.warnings_test =
	'W1-W9': (test) ->
		sed([
				["Здесь убивают слоников", "#Здесь warning"] #1
				["Здесь стоят гомосеки", "###Здесь стоит warning\n\n*А тут - ещё один"] #2 3
				["bluestreet`", "bluestreet`   \n   "] #4 5
				["Большой и ленивый город.", "   Большой и ненужный отступ."] #6
				["# Кронт", "непустая строка\n# Кронт"] #7
				["Пойти на Зелёную улицу", "Пойти на Зелёную улицу через точку."] #8
				["`kront-outer/bluestreet`", "`kront-outer/greenstreet`"] #9
			], "#{TMP_DIR}/Кронт - kront/map.ht.md"
		)
		result = parser.processDir "#{TMP_DIR}/Кронт - kront" #'unify/Кронт - kront'

		test.ok(result.warnings.some((w) -> w.id == "W#{i}"), "should generate warning number#{i}") for i in [1..9]
		test.strictEqual result.warnings.length, 9, 'should generate all warnings'
		test.deepEqual result.errors, [], 'should receive no errors'

		test.done()
	'W10': (test) ->
		sed([
				["`kront-outer/greenstreet`", "`kront-outer/greenstreet` text"] #10
				["### Другая голубая улица `bluestreet`", "### Другая голубая улица `bluestreet` text"] #10
			], "#{TMP_DIR}/Кронт - kront/map.ht.md"
		)
		result = parser.processDir "#{TMP_DIR}/Кронт - kront" #'unify/Кронт - kront'
		
		test.strictEqual result.warnings[0].id, 'W10', 'should get warn 10'
		test.strictEqual result.warnings[1].id, 'W10', 'should get another warn 10'
		test.strictEqual result.warnings.length, 2, 'should generate warnings for both cases'
		test.deepEqual result.errors, [], 'should receive no errors'
		
		test.done()


testOneError = (test, errId, sedWhat, sedByWhat, sedWhere="#{TMP_DIR}/Кронт - kront/map.ht.md") ->
	sed [[sedWhat, sedByWhat]], sedWhere
	result = parser.processDir "#{TMP_DIR}/Кронт - kront"
	
	test.ok result.errors.some((e) -> e.id == errId), 'should return specific error'
	#test.strictEqual result.errors.length, 1, 'should not generate extra errors'
	test.deepEqual result.warnings, [], 'should receive no warnings'
	
	test.done()


exports.error_E1_test = (test) ->
	testOneError(
		test, 'E1'
		"`kront-outer/bluestreet`"
		"`kront-outer/no-such-street`"
	)


exports.error_E2_test = (test) ->
	testOneError(
		test, 'E2'
		"* Пойти на Зелёную улицу `kront-outer/greenstreet`"
		"* Пойти на Зелёную улицу без метки"
	)


exports.error_E3_test = (test) ->
	testOneError(
		test, 'E3'
		"### Другая голубая улица `bluestreet`"
		"### Другая голубая улица и тоже без метки"
	)


exports.error_E4_test = (test) ->
	fs.renameSync "#{TMP_DIR}/Кронт - kront", "#{TMP_DIR}/Кронт"
	result = parser.processDir "#{TMP_DIR}/Кронт"
	
	test.ok result.errors.some((e) -> e.id == 'E4'), 'should return specific error'
	test.deepEqual result.warnings, [], 'should receive no warnings'
	
	test.done()


exports.error_E5_test = (test) ->
	testOneError(
		test, 'E5'
		"# Кронт"
		"# Тнорк"
	)


exports.error_E6_test = (test) ->
	testOneError(
		test, 'E6'
		"### Зелёная улица `greenstreet` (default)"
		"### Зелёная улица `greenstreet`"
		"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer/map.ht.md"
	)


exports.error_E7_test = (test) ->
	testOneError(
		test, 'E7'
		"### Голубая улица `bluestreet`"
		"### Голубая улица `greenstreet`"
		"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer/map.ht.md"
	)


exports.error_E8_test = (test) ->
	test.done() #the hardest one


exports.error_E9_test = (test) ->
	testOneError(
		test, 'E9'
		"### Другая голубая улица `bluestreet`"
		"### Другая голубая улица `bluestreet`\n![img](img)\n![moar](moat)"
	)


exports.error_E10_test = (test) ->
	testOneError(
		test, 'E10'
		"### Другая голубая улица `bluestreet`"
		"### Другая голубая улица `bluestreet`\n![paths_are](different.png)"
	)


exports.error_E11_test = (test) ->
	testOneError(
		test, 'E11'
		"### Другая голубая улица `bluestreet`"
		"### Другая голубая улица `bluestreet` (default)"
	)

exports.error_E12_test = (test) ->
	testOneError(
		test, 'E12'
		"# Кронт"
		"# Кронт\n# Кронта много не бывает"
	)

exports.error_E13_test = (test) ->
	testOneError(
		test, 'E13'
		"# Кронт"
		"# Кронт\n* какой-то переход `куда-то`"
	)

exports.error_E14_test = (test) ->
	testOneError(
		test, 'E14'
		"Большой и ленивый город."
		"Большой и ленивый город.\n![image](image)"
	)

exports.error_E15_test = (test) ->
	copy(
		"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer"
		"#{TMP_DIR}/Кронт - kront/Окрестности Кронта2 - outer"
		(error) ->
			throw error if error
			
			testOneError(
				test, 'E15'
				"# Окрестности Кронта"
				"# Окрестности Кронта2"
				"#{TMP_DIR}/Кронт - kront/Окрестности Кронта2 - outer/map.ht.md"
			)
	)


exports.save = ((test) ->
	try
		parseResult = parser.processDir "#{TMP_DIR}/Кронт - kront"
		conn = anyDB.createConnection config.DATABASE_URL_TEST
		conn.query.sync conn, "DROP TABLE IF EXISTS revision, areas, locations"
		mg.migrate.sync null, conn, {table: 'areas'}
		mg.migrate.sync null, conn, {table: 'locations'}
		parseResult.save(conn)
		
		result = conn.query.sync conn, 'SELECT count(*) AS cnt FROM areas'
		test.equal result.rows[0].cnt, parseResult.areas.length, 'should save all areas'
		result = conn.query.sync conn, 'SELECT count(*) AS cnt FROM locations'
		test.equal result.rows[0].cnt, parseResult.locations.length, 'should save all locations'
	catch e
		test.ifError e
	test.done()
).async()

