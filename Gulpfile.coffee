gulp = require 'gulp'
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


gulp.task 'default', ['warn', 'build']


gulp.task 'warn', (done) ->
	console.log chalk.red 'Warning: gulp support is experimental, better use Grunt instead.'
	done()


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
