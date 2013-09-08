"use strict";

var math = require('../utils/math.js');

exports.ap = function (test) {
	test.strictEqual(153, math.ap(3,6,9), 'should calculate result');
	test.done();
}
