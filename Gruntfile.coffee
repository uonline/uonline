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

module.exports = (grunt) ->

	# Project configuration.
	grunt.initConfig
		nodeunit:
			all: [
				'tests_node/health-check.js'
				'tests_node/*.coffee'
				'tests_node/*.js'
			]

		jshint:
			options:
				jshintrc: '.jshintrc'
				# reporter: './node_modules/jshint/src/reporters/non_error.js',
			all:
				src: [
					'*.js'
					'utils/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
				]

		browserify:
			all:
				src: './utils/validation.js'
				dest: './browserified/validation.js'
				options:
					standalone: 'validation'

		uglify:
			all:
				src: './browserified/validation.js'
				dest: './browserified/validation.min.js'

		checklicense:
			all:
				expand: true
				src: [
					'*.js'
					'utils/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'utils/*.coffee'
					'tests_node/*.coffee'
					'grunt-custom-tasks/*.coffee'
				]

		checkstrict:
			all:
				expand: true
				src: [
					'*.js'
					'utils/*.js'
					'tests_node/*.js'
					'grunt-custom-tasks/*.js'
					'*.coffee'
					'utils/*.coffee'
					'tests_node/*.coffee'
					'grunt-custom-tasks/*.coffee'
				]

		coffee:
			all:
				expand: true
				src: [
					'utils/*.coffee'
				]
				ext: '.js'

			options:
				bare: true

		clean:
			coffee: [
				'utils/validation.js'
			]

		coffeelint:
			all: [
				'*.coffee'
				'utils/*.coffee'
				'tests_node/*.coffee'
				'grunt-custom-tasks/*.coffee'
			]
			options: JSON.parse require('fs').readFileSync('.coffeelintrc').toString()


	# These plugins provide necessary tasks.
	require('load-grunt-tasks')(grunt)
	grunt.loadTasks './grunt-custom-tasks/'

	# Basic tasks.
	grunt.registerTask 'check', ['checkstrict', 'checklicense', 'coffeelint', 'jshint']
	grunt.registerTask 'build', ['browserify', 'uglify']
	grunt.registerTask 'test', ['nodeunit', 'jscoverage_report']

	# Custom one.
	grunt.registerTask 'ff', ['check', 'build']

	# Default task.
	grunt.registerTask 'default', ['check', 'build', 'test']
