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

jsc = require 'jscoverage'
jsc.enableCoverage true
fs = require 'fs'


parser = require '../lib/locparse.coffee'


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
	rmR 'tests_node/loctests_tmp' if fs.existsSync 'tests_node/loctests_tmp'
	done()


exports.tearDown = (done) ->
	rmR 'tests_node/loctests_tmp' if fs.existsSync 'tests_node/loctests_tmp'
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
	
	test.strictEqual result.warnings.length, 0, 'should receive no warnings'
	test.strictEqual result.errors.length, 0, 'should receive no errors'
	commonTest test, result
	
	test.done()


exports.warnings_test = (test) ->
	cpR 'tests_node/loctests', 'tests_node/loctests_tmp'
	sed([
			["Здесь убивают слоников", "#Здесь warning"] #1
			["Здесь стоят гомосеки", "###Здесь стоит warning\n\n*А тут - ещё один"] #2 3
			["bluestreet`", "bluestreet`   \n   "] #4 5
			["Большой и ленивый город.", "   Большой и ненужный отступ."] #6
			["# Кронт", "непустая строка\n# Кронт"] #7
			["Пойти на Зелёную улицу", "Пойти на Зелёную улицу через точку."] #8
			["`kront-outer/bluestreet`", "`kront-outer/greenstreet`"] #9
		], "tests_node/loctests_tmp/Кронт - kront/map.ht.md"
	)
	result = parser.processDir 'tests_node/loctests_tmp/Кронт - kront', true #'unify/Кронт - kront'
	
	test.strictEqual result.warnings.length, 9, 'shoulg generate all warnings'
	test.ok(result.warnings.some((w) -> w.id == "W#{i}"), "should generate warning number#{i}") for i in [1..9]
	test.strictEqual result.errors.length, 0, 'should receive no errors'
	
	test.done()

