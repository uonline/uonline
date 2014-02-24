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
			js: [
				'tests_node/health-check.js'
				'tests_node/*.js'
			]
			coffee: [
				'tests_node/health-check.coffee'
				'tests_node/*.coffee'
			]

		jshint:
			all:
				options:
					jshintrc: '.jshintrc'
				src: [
					'*.js'
					'lib/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
				]
			verbose:
				options:
					jshintrc: '.jshintrc'
					reporter: './node_modules/jshint/src/reporters/non_error.js'
				src: [
					'*.js'
					'lib/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
				]

		browserify:
			all:
				src: './lib/validation.js'
				dest: './browserified/validation.js'
				options:
					standalone: 'validation'

		uglify:
			all:
				src: './browserified/validation.js'
				dest: './browserified/validation.min.js'

		mustcontain:
			license:
				src: [
					'*.js'
					'lib/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'lib/*.coffee'
					'tests_node/*.coffee'
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
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'lib/*.coffee'
					'tests_node/*.coffee'
					'grunt-custom-tasks/*.coffee'
				]
				regex: /['"]use strict['"]\s*[;\n]/
				success: '{n} file{s} {is/are} strict.'
				fail: '{filename} is not strict.'
				fatal: false

		coffee:
			all:
				expand: true
				src: [
					'lib/*.coffee'
				]
				ext: '.js'

			options:
				bare: true

		clean:
			shit: [
				'lib-cov/*.coffee'
			]

		coffeelint:
			all: [
				'*.coffee'
				'lib/*.coffee'
				'tests_node/*.coffee'
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
			options:
				inputDirectory: 'lib'
				outputDirectory: 'lib-cov'


	# These plugins provide necessary tasks.
	require('load-grunt-tasks')(grunt)
	grunt.loadTasks './grunt-custom-tasks/'

	# Custom tasks.
	grunt.registerTask 'check', ['mustcontain', 'coffeelint', 'jshint:all']
	grunt.registerTask 'build', ['browserify', 'uglify']

	testTask = ['jscoverage', 'clean:shit', 'coffeeCoverage']  # order is important
	if grunt.option('single')?  # allow to test a single file, see Readme
		grunt.config.set 'nodeunit.one', [ 'tests_node/'+grunt.option('single') ]
		testTask.push 'nodeunit:one'
	else
		testTask = testTask.concat ['nodeunit:js', 'nodeunit:coffee']  # order is important
	testTask.push 'jscoverage_report'
	grunt.registerTask 'test', testTask

	# Default task.
	grunt.registerTask 'default', ['check', 'build', 'test']
