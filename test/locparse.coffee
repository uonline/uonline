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

NS = 'locparse'; exports[NS] = {}  # namespace
{test, requireCovered, legacyConfig} = require '../lib/test-utils.coffee'

anyDB = require 'any-db'
transaction = require 'any-db-transaction'
async = require 'asyncawait/async'
await = require 'asyncawait/await'
{promisify, promisifyAll} = require 'bluebird'
mg = require '../lib/migration'
fs = require 'fs'
rmrf = require 'rmrf'
copy = require('ncp').ncp
copy.limit = 16 #concurrency limit
copyAsync = promisify copy
TMP_DIR = 'test/loctests_tmp'

parser = requireCovered __dirname, '../lib/locparse.coffee'


krontShouldBeLike =
	id: 0
	name: 'Кронт'
	label: 'kront'
	description: 'Большой и ленивый город.\n\nЗдесь убивают слоников\nи разыгрывают туристов.'
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
		description: 'Здесь посажены деревья.\n\nИ грибы.\n\nИ животноводство.'
		actions:
			'kront/bluestreet': 'Пойти на Голубую улицу'
			'kront-outer/bluestreet': 'Пойти на другую Голубую улицу'
	]


sed = (pairs, file) ->
	data = fs.readFileSync(file, 'utf-8')
	for [oldStr, newStr] in pairs
		data = data.replace(oldStr, newStr)
	fs.writeFileSync file, data, 'utf-8'


exports[NS].beforeEach = async ->
	rmrf TMP_DIR if fs.existsSync TMP_DIR
	await copyAsync 'test/loctests', TMP_DIR


exports[NS].afterEach = ->
	rmrf TMP_DIR if fs.existsSync TMP_DIR


exports[NS].correct =
	'should parse all correctly and without errors and warnings': ->
		result = parser.processDir 'test/loctests/Кронт - kront'

		test.deepEqual result.warnings, [], 'should receive no warnings'
		test.deepEqual result.errors, [], 'should receive no errors'

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


exports[NS].warnings =
	'W1-W9': ->
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
		result = parser.processDir "#{TMP_DIR}/Кронт - kront"

		test.ok(result.warnings.some((w) -> w.id == "W#{i}"), "should generate warning number#{i}") for i in [1..9]
		test.strictEqual result.warnings.length, 9, 'should generate all warnings'
		test.deepEqual result.errors, [], 'should receive no errors'

	'W10': ->
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


testOneError = (test, errId, sedWhat, sedByWhat, sedWhere="#{TMP_DIR}/Кронт - kront/map.ht.md") ->
	sed [[sedWhat, sedByWhat]], sedWhere
	result = parser.processDir "#{TMP_DIR}/Кронт - kront"

	test.ok result.errors.some((e) -> e.id == errId), 'should return specific error'
	#test.strictEqual result.errors.length, 1, 'should not generate extra errors'
	test.deepEqual result.warnings, [], 'should receive no warnings'


exports[NS].errors =
	'E1': ->
		testOneError(
			test, 'E1'
			"`kront-outer/bluestreet`"
			"`kront-outer/no-such-street`"
		)

	'E2': ->
		testOneError(
			test, 'E2'
			"* Пойти на Зелёную улицу `kront-outer/greenstreet`"
			"* Пойти на Зелёную улицу без метки"
		)

	'E3': ->
		testOneError(
			test, 'E3'
			"### Другая голубая улица `bluestreet`"
			"### Другая голубая улица и тоже без метки"
		)

	'E4': ->
		fs.renameSync "#{TMP_DIR}/Кронт - kront", "#{TMP_DIR}/Кронт"
		result = parser.processDir "#{TMP_DIR}/Кронт"

		test.ok result.errors.some((e) -> e.id == 'E4'), 'should return specific error'
		test.deepEqual result.warnings, [], 'should receive no warnings'

	'E5': ->
		testOneError(
			test, 'E5'
			"# Кронт"
			"# Тнорк"
		)

	'E6': ->
		testOneError(
			test, 'E6'
			"### Зелёная улица `greenstreet` (initial)"
			"### Зелёная улица `greenstreet`"
			"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer/map.ht.md"
		)

	'E7': ->
		testOneError(
			test, 'E7'
			"### Голубая улица `bluestreet`"
			"### Голубая улица `greenstreet`"
			"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer/map.ht.md"
		)

	'E8': (done) ->
		done() #the hardest one

	'E9': ->
		testOneError(
			test, 'E9'
			"### Другая голубая улица `bluestreet`"
			"### Другая голубая улица `bluestreet`\n![img](img)\n![moar](moat)"
		)

	'E10': ->
		testOneError(
			test, 'E10'
			"### Другая голубая улица `bluestreet`"
			"### Другая голубая улица `bluestreet`\n![paths_are](different.png)"
		)

	'E11': ->
		testOneError(
			test, 'E11'
			"### Другая голубая улица `bluestreet`"
			"### Другая голубая улица `bluestreet` (initial)"
		)

	'E12': ->
		testOneError(
			test, 'E12'
			"# Кронт"
			"# Кронт\n# Кронта много не бывает"
		)

	'E13': ->
		testOneError(
			test, 'E13'
			"# Кронт"
			"# Кронт\n* какой-то переход `куда-то`"
		)

	'E14': ->
		testOneError(
			test, 'E14'
			"Большой и ленивый город."
			"Большой и ленивый город.\n![image](image)"
		)

	'E15': async ->
		await copyAsync(
			"#{TMP_DIR}/Кронт - kront/Окрестности Кронта - outer"
			"#{TMP_DIR}/Кронт - kront/Окрестности Кронта2 - outer"
		)
		testOneError(
			test, 'E15'
			"# Окрестности Кронта"
			"# Окрестности Кронта2"
			"#{TMP_DIR}/Кронт - kront/Окрестности Кронта2 - outer/map.ht.md"
		)


exports[NS].save =
	'should save all areas and locations': async ->
		_conn = promisifyAll anyDB.createConnection(legacyConfig.DATABASE_URL_TEST)
		await mg.migrate _conn
		conn = promisifyAll transaction(_conn)

		parseResult = parser.processDir "#{TMP_DIR}/Кронт - kront"
		await parseResult.save(conn)

		result = await conn.queryAsync 'SELECT count(*) AS cnt FROM areas'
		test.equal result.rows[0].cnt, parseResult.areas.length
		result = await conn.queryAsync 'SELECT count(*) AS cnt FROM locations'
		test.equal result.rows[0].cnt, parseResult.locations.length

		await conn.rollbackAsync()
