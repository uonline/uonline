/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


'use strict';

module.exports = function(grunt) {

	// Project configuration.
	grunt.initConfig({
		nodeunit: {
			all: ['tests_node/*.js'],
		},
		jshint: {
			options: {
				jshintrc: '.jshintrc',
				// reporter: './node_modules/jshint/src/reporters/non_error.js',
			},
			all: {
				src: ['Gruntfile.js', '*.js', 'utils/*.js', 'tests_node/*.js'],
			},
		},
		browserify: {
			all: {
				src: './utils/validation.js',
				dest: './browserified/validation.js',
				options: {
					standalone: 'validation',
				},
			},
		},
		uglify: {
			all: {
				src: './browserified/validation.js',
				dest: './browserified/validation.min.js',
			},
		},
		checklicense: {
			all: {
				expand: true,
				src: ['Gruntfile.js', '*.js', 'utils/*.js', 'tests_node/*.js'],
			},
		},
		checkstrict: {
			all: {
				expand: true,
				src: ['Gruntfile.js', '*.js', 'utils/*.js', 'tests_node/*.js'],
			},
		},
	});

	// These plugins provide necessary tasks.
	grunt.loadNpmTasks('grunt-contrib-nodeunit');
	grunt.loadNpmTasks('grunt-contrib-jshint');
	grunt.loadNpmTasks('grunt-browserify');
	grunt.loadNpmTasks('grunt-contrib-uglify');
	grunt.loadTasks('./grunt-custom-tasks/');

	// Browser build task.
	grunt.registerTask('ff',
		['browserify', 'uglify']);
	// Default task.
	grunt.registerTask('default',
		['checkstrict', 'checklicense', 'jshint', 'browserify', 'uglify', 'nodeunit', 'jscoverage_report']);

};
