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

through2 = require 'through2'
chalk = require 'chalk'

module.exports = (opts) ->

	checkedFiles = 0
	options = opts

	return through2.obj (file, enc, done) ->

		if file.isNull()
			# pass along
			@push file
			done()
			return

		if file.isStream()
			throw new Error 'Streaming not supported'
			done()
			return

		#file.inspect = undefined
		#console.log require('util').inspect file

		file.base = file.cwd

		checkedFiles++
		if options.regex.test(file.contents.toString()) is false
			msg = options.fail
			msg = msg.replace /\{filename\}/g, chalk.red file.relative
			console.log "#{msg}"

		@push file
		done()
