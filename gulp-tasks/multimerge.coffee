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

module.exports = (merge) ->
	(streams...) ->
		if streams.length is 1
			return streams[0]
		if streams.length is 2
			return merge streams[0], streams[1]
		if streams.length > 2
			out = merge streams[0], streams[1]
			for i in [2...streams.length]
				#console.log "Merging in stream ##{i}"
				out = merge out, streams[i]
			return out
