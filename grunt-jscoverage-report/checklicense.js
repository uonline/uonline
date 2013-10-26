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
	grunt.registerMultiTask('checklicense', 'Check if every file contains a license.', function() {
		var done = this.async();
		var fs = require('fs');
		var async = require('async');
		async.map(
			this.files,
			function (item, callback) {
				fs.readFile(item.src[0], function (error, data) {
					if (!!error)
					{
						callback(error, null);
					}
					else
					{
						callback(null, [item.src[0], ( /WARRANTY/ ).test(data.toString())]);
					}
				});
			},
			function (error, results) {
				async.filter(
					results,
					function (item, callback) {
						callback(!item[1]);
					},
					function(results) {
						if (results.length === 0)
						{
							grunt.log.ok('All files contain a license.');
						}
						else
						{
							for (var i in results)
							{
								grunt.log.warn(results[i][0]+' does not contain a license.');
							}
						}
						done();
					}
				);
			}
		);
	});
};
