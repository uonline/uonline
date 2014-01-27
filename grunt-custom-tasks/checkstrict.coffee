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
	# Please see the Grunt documentation for more information regarding task
	# creation: http://gruntjs.com/creating-tasks
	grunt.registerMultiTask 'checkstrict', 'Check if every file is in strict mode.', ->
		done = @async()
		fs = require 'fs'
		async = require 'async'
		async.map @filesSrc, ((item, callback) ->
			fs.readFile item, (error, data) ->
				if error?
					callback error, null
				else
					callback null, [item, ( /['"]use strict['"]\s*[;\n]/ ).test(data.toString())]
		), (error, results) ->
			if error?
				grunt.log.error error
				done(false)
			count = results.length
			results = results.filter (item) -> item[1] is false
			if results.length is 0
				grunt.log.ok "#{count} files are strict."
			else
				for i in results
					grunt.log.warn "#{i[0]} is not strict."
			done()
