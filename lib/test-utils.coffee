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


# Chai, its extensions and customizations

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


# App config

ask = require 'require-r'
exports.config = ask 'config/test'


# require() with coverage

fs = require 'fs'

requireFromString = (src, filename) ->
	Module = module.constructor
	m = new Module()
	m.paths = module.paths
	#console.log "Paths: #{m.paths}"
	m._compile(src, filename)
	return m.exports

cover = (filename) ->
	root = require 'root-path'
	cc = require 'coffee-coverage'
	ci = new cc.CoverageInstrumentor(basePath: root(), path: 'relative')
	tmp = ci.instrumentFile(filename)
	return requireFromString "#{tmp.init}#{tmp.js}", filename

exports.requireCovered = (dirname, filename) ->
	path = require 'path'
	filename = path.resolve(dirname, filename)
	#filename = path.relative(__dirname, filename)
	if fs.lstatSync(filename).isDirectory()
		filename += '/index.coffee'
	return cover(filename)

exports.askCovered = (filename) ->
	root = require 'root-path'
	filename = root(filename)
	if fs.lstatSync(filename).isDirectory()
		filename += '/index.coffee'
	return cover(filename)
