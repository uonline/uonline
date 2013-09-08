"use strict";

var tables = require('../utils/tables.js');

var anyDB = require('any-db');
var dbURL = 'mysql://anonymous:nopassword@localhost/uonline';
var conn = null;

exports.setUp = function (done) {
	conn = anyDB.createConnection(dbURL);
	done();
}

exports.tearDown = function (done) {
	conn.end();
	done();
}

exports.tableExists = function (test) {
	conn.query('CREATE TABLE testtable (id INT NOT NULL)', [], function(err, res){
		test.ifError(err);
		tables.tableExists(conn, 'uonline', 'testtable', function(err, res){
			test.ifError(err);
			test.strictEqual(res, true, 'table should exist after created');
			conn.query('DROP TABLE testtable', [], function(err, res){
				test.ifError(err);
				tables.tableExists(conn, 'uonline', 'testtable', function(err, res){
					test.ifError(err);
					test.strictEqual(res, true, 'table should not exist after dropped');
					test.done();
				});
			});
		});
	});

	//test.done();
}
