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

require '../lib/strings'


reportFile = (filename, data, log) ->
	log "SF:#{filename}"
	data.source.forEach (line, num) ->
		# increase the line number, as JS arrays are zero-based
		num++
		if data[num] isnt undefined
			log "DA:#{num},#{data[num]}"
	log 'end_of_record'


module.exports = (grunt) ->
	# Please see the Grunt documentation for more information regarding task
	# creation: http://gruntjs.com/creating-tasks
	grunt.registerTask 'jscoverage_write_lcov', 'Write jscoverage report in lcov format to file.', ->
		cov = (global or window)._$jscoverage or {}
		output = ''
		log = (x) ->
			output = "#{output}#{x}\n"
		Object.keys(cov).forEach (filename) ->
			data = cov[filename]
			reportFile(filename, data, log)
		try
			require('fs').writeFileSync('./report.lcov', output)
			grunt.log.ok 'report.lcov'
		catch error
			grunt.fail.warn(error)
