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

chai = require 'chai'
chai.use require 'chai-as-promised'


exports.test = chai.assert


exports.test.throwsPgError = (fn, code) ->
	try
		fn()
	catch ex
		exports.test.strictEqual ex.code, code
		return
	throw new Error "Expected block to throw PG error with code #{code}"


exports.test.isRejectedWithPgError = (promise, code) ->
	return promise.then(
		(ok) -> throw new Error "Expected block to throw PG error with code #{code}"
		(ex) -> exports.test.strictEqual ex.code, code
	)


exports.requireCovered = require '../require-covered.coffee'


exports.config = require '../config.coffee'
