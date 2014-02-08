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


deepIn = (actual, expected, message) ->
	test.fail(actual, expected, arguments.callee, "deepIn", message)

parser = require '../utils/locparse.coffee'


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
		description: 'Здесь сидят гомосеки.'
		actions:
			'kront-outer/greenstreet': 'Пойти на Зелёную улицу'
	,
		id: 0
		area: null
		name: 'Зелёная улица'
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


sed = (oldStr, newStr, file) ->
	data = fs.readFileSync(file, 'utf-8').replace(oldStr, newStr)
	fs.writeFileSync file, data, 'utf-8'


exports.setUp = (done) ->
	parser.reset()
	rmR 'tests_node/loctests_tmp' if fs.existsSync 'tests_node/loctests_tmp'
	done()


exports.tearDown = (done) ->
	done()


exports.correct_test = (test) ->
	parser.processDir 'tests_node/loctests/Кронт - kront' #'unify/Кронт - kront'
	[first, second] = parser.areas
	
	for obj in parser.areas.concat parser.locations
		test.ok(obj.id >= 0 and obj.id < 0x80000000)
		obj.id = 0
	
	for area in parser.areas
		for loc in area.locations
			test.strictEqual area, loc.area
			loc.area = null
	
	test.deepEqual krontShouldBeLike, first
	test.deepEqual outerShouldBeLike, second
	
	test.done()


exports.warnings_test = (test) ->
	cpR 'tests_node/loctests', 'tests_node/loctests_tmp'
	parser.processDir 'tests_node/loctests_tmp/Кронт - kront' #'unify/Кронт - kront'
	[first, second] = parser.areas
	
	for obj in parser.areas.concat parser.locations
		test.ok(obj.id >= 0 and obj.id < 0x80000000)
		obj.id = 0
	
	for area in parser.areas
		for loc in area.locations
			test.strictEqual area, loc.area
			loc.area = null
	
	test.deepEqual krontShouldBeLike, first
	test.deepEqual outerShouldBeLike, second
	
	test.done()
