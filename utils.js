/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


"use strict";

var list = require('fs').readdirSync('./utils');
for (var i in list)
{
	i = list[i];
	var name = i.substring(0, i.length-3); // ".js".length === 3
	var ext = i.substring(i.length-3);
	if (ext === '.js')
	{
		exports[name] = require('./utils/'+i);
	}
}
