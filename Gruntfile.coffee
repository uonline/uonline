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

		checklicense:
			all:
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

		checkstrict:
			all:
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
			coffee: [
				'lib/validation.js'
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
				exclude: 'locparse.coffee,strings.coffee'


	# These plugins provide necessary tasks.
	require('load-grunt-tasks')(grunt)
	grunt.loadTasks './grunt-custom-tasks/'

	# Basic tasks.
	grunt.registerTask 'check', ['checkstrict', 'checklicense', 'coffeelint', 'jshint:all']
	grunt.registerTask 'build', ['browserify', 'uglify']
	grunt.registerTask 'test', [
		'jscoverage', 'coffeeCoverage',    # order is important
		'nodeunit:js', 'nodeunit:coffee',  # order is important
		'jscoverage_report'
	]
	if grunt.option('single')?
		grunt.config.set 'nodeunit.one', [ 'tests_node/'+grunt.option('single') ]
		grunt.registerTask 'test', [
			'jscoverage', 'coffeeCoverage',    # order is important
			'nodeunit:one',
			'jscoverage_report'
		]

	# Custom one.
	grunt.registerTask 'ff', ['check', 'build']

	# Default task.
	grunt.registerTask 'default', ['check', 'build', 'test']
