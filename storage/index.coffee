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
{async, await} = require 'asyncawait'

exports.spawn = async (storageConfig) ->
	result = {}
	for i in storageConfig
		# Get storage spawner of given type
		spawner = ask "storage/#{i.type}"
		# Spawn the storage
		storage = await spawner.spawn(i.params)
		# Assign names to it
		names = i.names
		if i.name? then names = [i.name]
		for name in names
			result[name] = storage
	return result
