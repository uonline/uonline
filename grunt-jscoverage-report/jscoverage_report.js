/*
 * grunt-jscoverage-report
 *
 *
 * Copyright (c) 2013 m1kc (Max Musatov)
 * Licensed under the AGPLv3 license.
 */

'use strict';

module.exports = function(grunt) {
	// Please see the Grunt documentation for more information regarding task
	// creation: http://gruntjs.com/creating-tasks
	grunt.registerTask('jscoverage_report', 'Shows jscoverage report.', function() {
		grunt.task.requires('nodeunit');
		var jsc = require('jscoverage');
		jsc.coverage(); // print summary info, cover percent
		jsc.coverageDetail(); // print uncovered lines
	});
};
