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
TMP_DIR = 'tests_node/loctests_tmp'

krontShouldBeLike =
	id: 0
	name: 'Кронт'
	label: 'kront'
	description: 'Большой и ленивый город.\nЗдесь убивают слоников и разыгрывают туристов.'
	locations: [
		id: 0
		area: null
		name: 'Другая голубая улица'
		image: null
		label: 'kront/bluestreet'
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
		image: null
		label: 'kront-outer/bluestreet'
		description: 'Здесь сидят гомосеки.'
		actions:
			'kront-outer/greenstreet': 'Пойти на Зелёную улицу'
	,
		id: 0
		area: null
		name: 'Зелёная улица'
		image: 'животноводство.png'
		label: 'kront-outer/greenstreet'
		description: 'Здесь посажены деревья.\nИ грибы.\nИ животноводство.'
		actions:
			'kront/bluestreet': 'Пойти на Голубую улицу'
			'kront-outer/bluestreet': 'Пойти на другую Голубую улицу'
	]


cpR = (src, dst) ->
	fs.mkdirSync dst
	srcFiles = fs.readdirSync(src)
	for srcName in srcFiles
		srcPath = "#{src}/#{srcName}"
		dstPath = "#{dst}/#{srcName}"
		if fs.statSync(srcPath).isDirectory()
			cpR srcPath, dstPath
		else
			fs.writeFileSync dstPath, fs.readFileSync(srcPath)
			#fs.createReadStream(srcPath).pipe(fs.createWriteStream(dstPath))


rmR = (dir) ->
	files = fs.readdirSync(dir)
	for name in files
		path = "#{dir}/#{name}"
		if fs.statSync(path).isDirectory()
			rmR path
		else
			fs.unlinkSync path
	fs.rmdirSync dir


sed = (pairs, file) ->
	data = fs.readFileSync(file, 'utf-8')
	for pair in pairs
		[oldStr, newStr] = pair
		data = data.replace(oldStr, newStr)
	fs.writeFileSync file, data, 'utf-8'


exports.setUp = (done) ->
	rmR TMP_DIR if fs.existsSync TMP_DIR
	cpR 'tests_node/loctests', TMP_DIR
	done()


exports.tearDown = (done) ->
	rmR TMP_DIR if fs.existsSync TMP_DIR
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
	result = parser.processDir 'tests_node/loctests/Кронт - kront' #'unify/Кронт - kront'

	test.deepEqual result.warnings, [], 'should receive no warnings'
	test.deepEqual result.errors, [], 'should receive no errors'
	commonTest test, result

	test.done()


exports.warnings_test = (test) ->
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

