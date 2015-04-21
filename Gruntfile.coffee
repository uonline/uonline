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

module.exports = (grunt) ->

	# Project configuration.
	grunt.initConfig
		nodeunit:
			all: [
				'tests/health-check.js'
				'tests/health-check.coffee'
				'tests/*.js'
				'tests/*.coffee'
			]
			options:
				reporter: 'grunt'

		jshint:
			all:
				options:
					jshintrc: '.jshintrc'
				src: [
					'*.js'
					'lib/*.js'
					'tests/*.js'
					'grunt-custom-tasks/*.js'
				]
			verbose:
				options:
					jshintrc: '.jshintrc'
					reporter: './node_modules/jshint/src/reporters/non_error.js'
				src: [
					'*.js'
					'lib/*.js'
					'tests/*.js'
					'grunt-custom-tasks/*.js'
				]

		browserify:
			all:
				src: []
				dest: './_build/validation.js'
			options:
				require: ['./lib/validation.coffee:validation']
				transform: ['coffeeify']

		concat:
			scripts:
				src: [
					'./bower_components/jquery/dist/jquery.min.js'
					'./bower_components/bootstrap/dist/js/bootstrap.min.js'
					'./bower_components/jquery-pjax/jquery.pjax.js'
					'./_build/validation.js'
					'./_build/browser.js'
				]
				dest: './_build/all.js'

		uglify:
			all:
				src: './_build/all.js'
				dest: './assets/scripts.js'

		mustcontain:
			license:
				src: [
					'*.js'
					'lib/*.js'
					'tests/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'lib/*.coffee'
					'tests/*.coffee'
					'grunt-custom-tasks/*.coffee'
				]
				regex: /WARRANTY/
				success: '{n} file{s} contain{!s} a license.'
				fail: '{filename} does not contain a license.'
				fatal: false
			strict:
				src: [
					'*.js'
					'lib/*.js'
					'tests/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'lib/*.coffee'
					'tests/*.coffee'
					'grunt-custom-tasks/*.coffee'
				]
				regex: /['"]use strict['"]\s*[;\n]/
				success: '{n} file{s} {is/are} strict.'
				fail: '{filename} is not strict.'
				fatal: false

		coffee:
			browser:
				src: './browser.coffee'
				dest: './_build/browser.js'
			options:
				bare: false

		coffeelint:
			all: [
				'*.coffee'
				'lib/*.coffee'
				'tests/*.coffee'
				'grunt-custom-tasks/*.coffee'
			]
			options: JSON.parse fs.readFileSync('.coffeelintrc', 'utf-8')

		coffeeCoverage:
			options:
				path: 'relative'
			all:
				expand: true
				cwd: 'lib/'
				src: ['*.coffee']
				dest: 'lib-cov/'
				ext: '.js'

		jscoverage:
			all:
				expand: true
				cwd: 'lib/'
				src: ['*.js']
				dest: 'lib-cov/'
				ext: '.js'

		clean:
			lib_cov: 'lib-cov/'

		mkdir:
			lib_cov:
				options:
					create: ['lib-cov/']

		codo:
			all:
				src: './lib/'
				dest: './docs/'
			options:
				name: 'uonline'
				title: 'uonline documentation'
				undocumented: yes
				stats: no

		coveralls:
			all:
				src: 'report.lcov'
			options:
				force: true

		jscoverage_report:
			options:
				#showOnly: /^lib[/]/
				showOnly: /.*/


	# These plugins provide necessary tasks.
	#require('time-grunt')(grunt)
	require('jit-grunt')(grunt)

	# Custom plugins.
	grunt.loadTasks './grunt-custom-tasks/'

	# Custom tasks.
	grunt.registerTask 'check', ['mustcontain', 'coffeelint', 'jshint:all']
	grunt.registerTask 'build', ['browserify', 'coffee', 'concat', 'uglify']
	grunt.registerTask 'docs', ['codo']

	testTask = []#['clean:lib_cov', 'mkdir:lib_cov', 'jscoverage', 'coffeeCoverage']
	if grunt.option('single')?  # allow to test a single file, see Readme
		grunt.config.set 'nodeunit.one', [ 'tests/'+grunt.option('single') ]
		testTask.push 'nodeunit:one'
	else
		testTask.push 'nodeunit:all'
	testTask.push 'jscoverage_report'
	grunt.registerTask 'test', testTask

	# Default task.
	grunt.registerTask 'default', ['check', 'build', 'docs', 'test']

	# And some additional CI stuff.
	grunt.registerTask 'travis', ['default', 'jscoverage_write_lcov', 'coveralls']
