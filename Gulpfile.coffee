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
