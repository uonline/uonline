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

var prettyprint = jsc.require(module, '../utils/prettyprint.js');

exports.spaces = function (test) {
	test.strictEqual(prettyprint.spaces(0), '', 'should return empty string when I ask for 0 spaces');
	test.strictEqual(prettyprint.spaces(1), ' ', 'should return given number of spaces');
	test.strictEqual(prettyprint.spaces(4), '    ', 'should return given number of spaces');
	test.done();
};

exports.writeln = function(test) {
	test.expect(1);
	var targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, 'Nikolai Baskov is up and running.', 'should print text');
	};
	prettyprint.writeln('Nikolai Baskov is up and running.', targetConsole);
	test.done();
};

exports.section = function(test) {
	test.expect(4);
	var targetConsole;
	var result;

	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, 'Killing...', 'should print text without offset at first call');
	};
	result = prettyprint.section('Killing', targetConsole);
	test.strictEqual(result, 2, 'should increase offset by 2 every time');

	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, '  Killing...', 'should print text with offset');
	};
	result = prettyprint.section('Killing', targetConsole);
	test.strictEqual(result, 4, 'should increase offset by 2 every time');

	prettyprint.endSection();
	prettyprint.endSection();

	test.done();
};

exports.endSection = function(test) {
	var targetConsole;
	var result;
	targetConsole = {};
	targetConsole.log = function(text) {
		// do nothing
	};

	result = prettyprint.section('some section', targetConsole);
	result = prettyprint.section('some section', targetConsole);
	result = prettyprint.endSection();
	test.strictEqual(result, 2, 'should decrease offset by 2');
	result = prettyprint.endSection();
	test.strictEqual(result, 0, 'should decrease offset by 2');

	test.done();
};

exports.action = function(test) {
	test.expect(3);
	var targetConsole;
	var result;

	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, 'Killing...', 'should print text with section offset');
	};
	prettyprint.action('Killing', targetConsole);

	targetConsole = {};
	targetConsole.log = function(text) {
		// do nothing
	};
	prettyprint.section('some section', targetConsole);
	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, '  Killing...', 'should print text with section offset');
	};
	prettyprint.action('Killing', targetConsole);
	prettyprint.endSection();

	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, 'Killing...', 'should print text with section offset');
	};
	prettyprint.action('Killing', targetConsole);

	test.done();
};

exports.result = function(test) {
	test.expect(1);
	var targetConsole;
	var result;

	targetConsole = {};
	targetConsole.log = function(text) {
		test.strictEqual(text, ' done', 'should print text with offset');
	};
	prettyprint.result('done', targetConsole);

	test.done();
};
