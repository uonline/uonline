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

requireFromString = (src, filename) ->
	Module = module.constructor
	m = new Module()
	m.paths = module.paths
	#console.log "Paths: #{m.paths}"
	m._compile(src, filename)
	return m.exports

module.exports = (dirname, filename) ->
	#console.log ">JSC: #{require('util').inspect global._$jscoverage}"
	filename = require('path').resolve(dirname, filename)
	cc = require 'coffee-coverage'
	ci = new cc.CoverageInstrumentor()
	tmp = ci.instrumentFile(filename)
	#console.log "REQ: #{tmp.init}#{tmp.js}"
	return requireFromString "#{tmp.init}#{tmp.js}"
