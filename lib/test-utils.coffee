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

sync = require 'sync'


exports.test = require('chai').assert

exports.requireCovered = require '../require-covered.coffee'

# Wrapper. For the given function f, returns a function F which takes exactly
# one argument (callback), executes the original function f inside a sync fiber,
# and passes any exceptions or errors to the given callback of F.
#
# This wrapper is primarily used because the Function.async() function of sync
# library returns a function which is declared to take 0 arguments and tries
# to determine real arguments number in runtime. This creates a conflict with
# Mocha which relies on declared argument count to determine whether a function
# is synchronous or asynchronous.
exports.t = (func) ->
	return (done) ->
		sync func.bind(this), (error, result) ->
			done(error)

exports.config = require '../config.coffee'
