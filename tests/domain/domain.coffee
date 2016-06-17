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

ask = require 'require-r'
{test, requireCovered, askCovered, config} = ask 'lib/test-utils.coffee'
{async, await} = require 'asyncawait'
require 'sugar'


exports.useDB = ->


exports.spawn = async ->
	ds = ask 'domain'
	sc = ask 'storage'
	storage = await sc.spawn(config.storage)
	dc = await ds.spawn(config.domain, storage)
	test.isAbove Object.keys(dc).length, 0
