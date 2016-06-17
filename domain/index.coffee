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

exports.spawn = async (domainConfig, storage) ->
	result = {}
	for i in domainConfig
		# get domain spawner
		Domain = ask "domain/#{i.domain}/#{i.type}"
		# spawn domain with requested storage
		domain = new Domain(storage[i.storage])
		if domain.init?
			await domain.init()
		# save
		result[i.domain] = domain
	return result
