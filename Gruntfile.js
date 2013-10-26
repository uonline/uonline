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
	});

	// These plugins provide necessary tasks.
	grunt.loadNpmTasks('grunt-contrib-nodeunit');
	grunt.loadNpmTasks('grunt-contrib-jshint');
	grunt.loadNpmTasks('grunt-browserify');

	// Default task.
	grunt.registerTask('default', ['jshint', 'browserify', 'nodeunit']);

};
