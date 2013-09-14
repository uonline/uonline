var reporter = require('nodeunit').reporters.verbose; // may be: default, verbose, minimal, skip_passed
reporter.run(['tests_node/']);

var jsc = require('jscoverage');
process.on('exit', function () {
	jsc.coverage(); // print summary info, cover percent
	jsc.coverageDetail(); // print uncovered lines
});
