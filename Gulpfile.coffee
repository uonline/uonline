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
coffee = require 'gulp-coffee'
cleanDest = require 'gulp-clean-dest'
uglify = require 'gulp-uglify'
concat = require 'gulp-concat'
merge = require 'gulp-merge'
browserify = require 'browserify'
coffeeify = require 'coffeeify'
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'
require('gulp-grunt')(gulp)
notify = require 'gulp-notify'
mocha = require 'gulp-mocha'
console.timeEnd 'Loading deps'


saneMerge = (streams...) ->
	if streams.length is 1
		return streams[0]
	if streams.length is 2
		return merge streams[0], streams[1]
	if streams.length > 2
		out = merge streams[0], streams[1]
		for i in [2...streams.length]
			#console.log "Merging in stream ##{i}"
			out = merge out, streams[i]
		return out


gulp.task 'default', ->
	console.log chalk.green "Specify a task, like 'build' or 'watch'."


gulp.task 'build', ->
	return saneMerge(
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
	gulp
		.src ''
		.pipe notify 'Assets were rebuilt.'


gulp.task 'watch', ['build'], ->
	gulp.watch ['./browser.coffee', './lib/validation.coffee'], ['build-and-notify']


gulp.task 'mocha', ->
	return gulp
		.src 'tests_new/*'
		.pipe mocha(ui: 'exports', reporter: 'spec')

gulp.task 'coverage', ['mocha'], ->
	pseudogrunt =
		registerTask: (a,b,c) ->
			c.call({options: -> {}})
	require('./grunt-custom-tasks/jscoverage_report.coffee')(pseudogrunt)

gulp.task 'test', ['mocha', 'coverage']
