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


gulp.task 'default', ->
	console.log chalk.green "Specify a task, like 'build' or 'watch'."


gulp.task 'build', ->
	return merge(
		browserify()
		.transform coffeeify
		.require './lib/validation.coffee'  # TODO: use 'expose' option to use just require('validation')
		.bundle().pipe(source('validation.js')).pipe(buffer())  # epic wrapper, don't ask how does it work
		.pipe uglify()
	,
		gulp
		.src './browser.coffee'
		.pipe coffee()
		.pipe uglify()
	,
		gulp
		.src './bower_components/jquery/dist/jquery.min.js'
	,
		gulp
		.src './bower_components/bootstrap/dist/js/bootstrap.min.js'
	,
		gulp
		.src './bower_components/jquery-pjax/jquery.pjax.js'
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
