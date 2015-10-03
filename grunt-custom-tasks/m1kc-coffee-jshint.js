// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


'use strict';

var hintFiles = require("coffee-jshint/lib-js/hint");
var chalk = require('chalk');


module.exports = function(grunt) {

    // Please see the Grunt documentation for more information regarding task
    // creation: http://gruntjs.com/creating-tasks

    grunt.registerMultiTask('m1kc_coffee_jshint', 'grunt wrapper for coffee-jshint', function() {
        // Merge task-specific and/or target-specific options with these defaults.
        var options = this.options({
            jshintOptions: [],
            withDefaults: true,
            globals: []
        });
        var files = this.filesSrc;

        var errnum = 0;
        var fnum = 0;
        files.forEach(function(path) {
            var x = hintFile(path, options);
            fnum++;
            if (x.length > 0)
            {
                grunt.log.warn(x);
                errnum++;
            }
        });

        if (errnum === 0)
        {
            grunt.log.ok(fnum+" files lint free.");
        }
    });

    var hintFile = function(path, options) {

        var errors = hintFiles([path],
                               {options: options.jshintOptions,
                                withDefaults: options.withDefaults,
                                globals: options.globals},
                               false);
        var flattened_errors = [].concat.apply([], errors);
        var formatted_errors = flattened_errors.map(function(error) {
            return chalk.magenta(path + ': ' + error.line + ":" + error.character) + " " + error.reason;
        });

        return formatted_errors.join('\n');
    };

};
