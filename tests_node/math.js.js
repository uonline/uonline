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

var jsc = require('jscoverage');
jsc.enableCoverage(true);
function coverageReport(){ jsc.coverage(); jsc.coverageDetail(); }

var math = jsc.require(module, '../utils/math.js');

exports.ap = function (test) {
	test.strictEqual(153, math.ap(3,6,9), 'should calculate result');
	test.done();
};
