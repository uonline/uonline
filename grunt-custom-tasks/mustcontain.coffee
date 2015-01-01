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
	grunt.registerMultiTask 'mustcontain', 'Check if every file contains specified things.', ->
		done = @async()
		fs = require 'fs'
		async = require 'async'
		regex = @data.regex
		success = @data.success
		fail = @data.fail
		fatal = @data.fatal

		async.map @filesSrc, ((item, callback) ->
			fs.readFile item, (error, data) ->
				if error?
					callback error, null
				else
					callback null, [item, regex.test(data.toString())]
		), (error, results) ->
			if error?
				grunt.log.error error
				done(false)
			count = results.length
			results = results.filter (item) -> item[1] is false
			if results.length is 0
				msg = success.replace /\{n\}/g, "#{count}"
				if count == 1 or (count % 10 == 1 and count % 100 != 11)
					msg = msg.replace /\{s\}/g, ''
					msg = msg.replace /\{\!s\}/g, 's'
					msg = msg.replace /\{is\/are\}/g, 'is'
				else
					msg = msg.replace /\{s\}/g, 's'
					msg = msg.replace /\{\!s\}/g, ''
					msg = msg.replace /\{is\/are\}/g, 'are'
				grunt.log.ok msg
				done()
			else
				for i in results
					msg = fail.replace /\{filename\}/g, "#{i[0]}"
					grunt.log.warn msg
				done(not fatal)
