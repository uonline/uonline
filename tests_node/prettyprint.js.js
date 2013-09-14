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

var prettyprint = require('../utils/prettyprint.js');

exports.spaces = function (test) {
	test.strictEqual(prettyprint.spaces(0), '', 'should return empty string when I ask for 0 spaces');
	test.strictEqual(prettyprint.spaces(1), ' ', 'should return given number of spaces');
	test.strictEqual(prettyprint.spaces(4), '    ', 'should return given number of spaces');
	test.done();
};
