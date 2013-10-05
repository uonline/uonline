'use strict';

module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    nodeunit: {
      files: ['tests_node/*.js'],
    },
    jshint: {
      options: {
        jshintrc: '.jshintrc'
      },
      gruntfile: {
        src: 'Gruntfile.js'
      },
      root: {
        src: ['*.js']
      },
      lib: {
        src: ['utils/*.js']
      },
      test: {
        src: ['tests_node/*.js']
      },
    },
    jscoverage: {
      options: {
        inputDirectory: 'utils',
        outputDirectory: 'utils-cov'
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
