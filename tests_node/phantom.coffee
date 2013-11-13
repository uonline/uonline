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

async = require 'async'
phantom = require 'phantom'
ph = null
page = null


exports.setUp = (done) ->
	phantom.create (createdPh) ->
		ph = createdPh
		ph.createPage (createdPage) ->
			page = createdPage
			done()


exports.tearDown = (done) ->
	page.close()
	ph.exit()
	setTimeout (() -> done()), 50


wrapCallback = (callback) ->
	(result) -> callback(null, result)


exports.firstTest = (test) ->
	test.expect 2
	page.open "http://www.google.com", (status) ->
		test.strictEqual status, 'success', 'Should open Google'
		page.evaluate (-> document.title), (result) ->
			test.strictEqual result, 'Google', 'Should read its title'
			test.done()


exports.secondTest = (test) ->
	test.expect 3
	async.series [
		(callback) ->
			page.open 'http://www.google.com', wrapCallback(callback)
		(callback) ->
			page.evaluate (() -> document.title), wrapCallback(callback)
	],
	(error, result) ->
		test.ifError(error)
		test.strictEqual result[0], 'success', 'Should open Google'
		test.strictEqual result[1], 'Google', 'Should read its title'
		test.done()


exports['/404/'] = (test) ->
	#test.expect 3
	async.series [
		(callback) ->
			page.open 'http://localhost:5000/404/', wrapCallback(callback)
		(callback) ->
			page.evaluate (() ->
				document.getElementsByTagName('footer')[0].childNodes[1].innerHTML.indexOf('m1kc') > 0),
				wrapCallback(callback)
	],
	(error, result) ->
		test.ifError(error)
		test.strictEqual result[0], 'success', 'Should not fail'
		test.strictEqual result[1], true, 'Should render custom template'
		test.done()
