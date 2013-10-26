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
		['checklicense', 'jshint', 'browserify', 'uglify', 'nodeunit', 'jscoverage_report']);

};
