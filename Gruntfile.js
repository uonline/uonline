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
			},
			all: {
				src: ['Gruntfile.js', '*.js', 'utils/*.js', 'tests_node/*.js'],
			},
		},
		jscoverage: {
			options: {
				inputDirectory: 'utils',
				outputDirectory: 'utils-cov',
			}
		},
	});

	// These plugins provide necessary tasks.
	grunt.loadNpmTasks('grunt-contrib-nodeunit');
	grunt.loadNpmTasks('grunt-contrib-jshint');
	grunt.loadNpmTasks('grunt-jscoverage');

	// Default task.
	grunt.registerTask('default', ['jshint', 'nodeunit']);

};
