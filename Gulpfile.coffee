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

console.time 'Loading gulp'
gulp = require 'gulp'
console.timeEnd 'Loading gulp'

console.time 'Loading deps'
chalk = require 'chalk'
cleanDest = require 'gulp-clean-dest'
merge = require('./gulp-tasks/multimerge.coffee')(require('gulp-merge'))
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'
debug = require 'gulp-debug'
seq = require 'gulp-sequence'
args = require('get-gulp-args')()
console.timeEnd 'Loading deps'


gulp.task 'default', seq 'check', 'build', 'test'


gulp.task 'build', ->
	coffee = require 'gulp-coffee'
	uglify = require 'gulp-uglify'
	concat = require 'gulp-concat'
	browserify = require 'browserify'
	coffeeify = require 'coffeeify'
	return merge(
		gulp
		.src './bower_components/jquery/dist/jquery.min.js'
	,
		gulp
		.src './bower_components/bootstrap/dist/js/bootstrap.min.js'
	,
		gulp
		.src './bower_components/jquery-pjax/jquery.pjax.js'
		.pipe uglify()
	,
		gulp
		.src './browser.coffee'
		.pipe coffee()
		.pipe uglify()
	,
		browserify()
		.transform coffeeify
		.require './lib/validation.coffee', expose: 'validation'
		.bundle().pipe(source('validation.js')).pipe(buffer())  # epic wrapper, don't ask how does it work
		.pipe uglify()
	)
	.pipe concat 'scripts.js'
	.pipe cleanDest './assets'
	.pipe gulp.dest './assets'


gulp.task 'build-and-notify', ['build'], ->
	notify = require 'gulp-notify'
	return gulp
		.src ''
		.pipe notify 'Assets were rebuilt.'


gulp.task 'watch', ['build'], ->
	return gulp.watch ['./browser.coffee', './lib/validation.coffee'], ['build-and-notify']


gulp.task 'check', ->
	mustcontain = require './gulp-tasks/mustcontain.coffee'
	jshint = require 'gulp-jshint'
	coffeelint = require 'gulp-coffeelint'
	cj = require './gulp-tasks/coffee-jshint.coffee'

	gulpFilter = require 'gulp-filter'
	__jsOnly = gulpFilter ['**/*.js'], restore: true
	__coffeeOnly = gulpFilter ['**/*.coffee']#, restore: true

	return gulp
		.src [
			'*.js'
			'lib/*.js'
			'tests/*.js'
			'grunt-custom-tasks/*.js'
			'gulp-tasks/*.js'
			'*.coffee'
			'lib/*.coffee'
			'tests/*.coffee'
			'grunt-custom-tasks/*.coffee'
			'gulp-tasks/*.coffee'
		]

		.pipe mustcontain {
			regex: /WARRANTY/
			success: '{n} file{s} contain{!s} a license.'
			fail: '{filename}: does not contain a license.'
			fatal: false
		}
		.pipe mustcontain {
			regex: /['"]use strict['"]\s*[;\n]/
			success: '{n} file{s} {is/are} strict.'
			fail: '{filename}: is not in strict mode.'
			fatal: false
		}

		.pipe __jsOnly
		.pipe jshint()
		.pipe jshint.reporter 'default'
		.pipe __jsOnly.restore

		.pipe __coffeeOnly
		.pipe coffeelint './coffeelint.json'
		.pipe coffeelint.reporter()

		.pipe cj {
			jshintOptions: ['node', 'browser', 'jquery']
			withDefaults: true
			globals: ['_$jscoverage', 'confirm']
		}
		#.pipe __coffeeOnly.restore


gulp.task 'test', seq 'nodeunit', 'mocha', 'jscoverage-report', 'force-exit'


gulp.task 'mocha', ->
	mocha = require 'gulp-mocha'
	return gulp
		.src ['test/*.coffee']
		.pipe mocha(ui: 'exports')
	# TODO later: reporter dot
	# TODO later: use --reporter
	# TODO: --single


gulp.task 'nodeunit', ->
	nodeunit = require 'gulp-nodeunit-runner'
	reporter = 'minimal'
	sourcefiles = [
		'tests/health-check.js'
		'tests/health-check.coffee'
		'tests/*.js'
		'tests/*.coffee'
	]
	if args.single?
		sourcefiles = "tests/#{args.single}"
	if args.reporter?
		reporter = args.reporter
	imitate = require 'vinyl-imitate'
	return gulp
		.src sourcefiles
		.pipe nodeunit(reporter: reporter)


gulp.task 'force-exit', ->
	process.exit 0


gulp.task 'jscoverage-report', ->
	jscr = require './gulp-tasks/jscoverage-report.coffee'
	jscr()


gulp.task 'coveralls', ->
	jsc = require 'jscoverage'
	lcov = jsc.getLCOV()
	imitate = require 'vinyl-imitate'
	coveralls = require 'gulp-coveralls'
	return imitate('report.lcov', new Buffer(lcov))
		.pipe source('report.lcov')
		.pipe buffer()
		.pipe coveralls()


gulp.task 'travis', seq 'check', 'build', 'nodeunit', 'mocha', 'jscoverage-report', 'coveralls', 'force-exit'
