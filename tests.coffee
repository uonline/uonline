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

fs = require 'fs'
ask = require 'require-r'
{async, await} = require 'asyncawait'

{config} = ask 'lib/test-utils.coffee'
TESTS_DIR = 'tests'

pgPool = null
pg = null
useDB = {}


iter = (dirname) ->
	for fname in fs.readdirSync(dirname)
		fpath = dirname+'/'+fname
		if fs.statSync(fpath).isDirectory()
			iter(fpath)
		else if fname.endsWith('.coffee')
			test = ask fpath
			NS = fpath.substring(TESTS_DIR.length+1, fpath.length-7)
			useDB[NS] = test.useDB
			delete test.useDB
			exports[NS] = test
iter(TESTS_DIR)


exports.before = async ->
	pgPool = (await ask('storage').spawn(config.storage)).pgTest
	pg = await pgPool.connect()
	for NS of useDB
		useDB[NS]({pg})


exports.after = async ->
	pg.done()
