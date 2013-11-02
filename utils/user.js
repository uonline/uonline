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

var config = require('../config.js');

var crypto = require('crypto');
var async = require('async');

exports.userExists = function(dbConnection, username, callback)
{
	dbConnection.query(
		'SELECT count(*) AS result FROM `uniusers` WHERE user = ?',
		[username],
		function (error, result) {
			callback(error, !!error || (result.rows[0].result > 0));
		}
	);
};

exports.idExists = function(dbConnection, id, callback) {
	dbConnection.query(
		'SELECT count(*) AS result FROM `uniusers` WHERE `id`= ?',
		[id],
		function (error, result) {
			callback(error, !!error || (result.rows[0].result > 0));
		}
	);
};

exports.sessionExists = function(dbConnection, sess, callback) {
	dbConnection.query(
		'SELECT count(*) AS result FROM `uniusers` WHERE `sessid` = ?',
		[sess],
		function (error, result) {
			if (!!error)
			{
				callback(error, null);
				return;
			}
			callback(null, (result.rows[0].result > 0));
		}
	);
};

exports.sessionInfoRefreshing = function(dbConnection, sessid, sess_timeexpire, callback) {
	if (!sessid)
	{
		callback(null, {sessionIsActive: false});
		return;
	}

	async.auto({
			getUser: function(callback) {
				dbConnection.query(
					'SELECT user, permissions FROM uniusers WHERE sessid = ? AND sessexpire > NOW()',
					[sessid], callback);
			},
			refresh: ['getUser', function (callback, results) {
				if (results.getUser.rowCount === 0)
				{
					callback(null, 'session does not exist or expired');
					return;
				}
				dbConnection.query(
					'UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL ? SECOND WHERE `sessid` = ?',
					[sess_timeexpire, sessid], callback);
			}],
		},
		function (error, results) {
			if (!!error)
			{
				callback(error, null);
				return;
			}
			if (results.refresh === 'session does not exist or expired')
			{
				callback(null, { sessionIsActive: false });
				return;
			}
			callback(null, {
				sessionIsActive: true,
				username: results.getUser.rows[0].user,
				admin: (results.getUser.rows[0].permissions === config.PERMISSIONS_ADMIN)
			});
		}
	);
};

exports.generateSessId = function(dbConnection, sess_length, callback) {
	//here random sessid must be checked for uniqueness
	//and it'll be!
	(function iteration()
	{
		var sessid = exports.createSalt(sess_length);
		exports.sessionExists(dbConnection, sessid, function(error, exists) {
			if (!!error)
			{
				callback(error, null);
				return;
			}
			if (exists)
			{
				iteration();
				return;
			}
			callback(null, sessid);
		});
	})();
};

exports.idBySession = function(dbConnection, sess, callback) {
	dbConnection.query(
		'SELECT `id` FROM `uniusers` WHERE `sessid` = ?',
		[sess],
		function (error, result) {
			if (!!result && result.rowCount === 0)
			{
				error = "Wrong user's id";
			}
			callback(error, !!error || result.rows[0].id);
		}
	);
};

exports.closeSession = function(dbConnection, sess, callback) {
	if (!sess)
	{
		callback(undefined, 'Not closing: empty sessid');
		return;
	}
	dbConnection.query(
		'UPDATE `uniusers` SET `sessexpire` = NOW() - INTERVAL 1 SECOND WHERE `sessid` = ?',
		[sess], callback
	);
};

exports.createSalt = function(sess_length) {
	var salt = '';
	var a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	for(var i=0; i<sess_length; i++) { salt += a[Math.floor(Math.random() * a.length)]; }
	return salt;
};

exports.registerUser = function (dbConnection, user, password, permissions, callback) {
	var salt = this.createSalt(16);
	/*crypto.pbkdf2(password, salt, 4096, 256, function(error, cryptedPassword){
		if (!!error) callback(error, undefined);
		dbConnection.query(
			'INSERT INTO `uniusers` '+
			'(`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) VALUES '+
			'(?, ?, ?, ?, NOW(), NOW() + INTERVAL ? SECOND, (SELECT id FROM locations WHERE `default` = 1), ?)',
			[user, salt, cryptedPassword, exports.generateSessId(), config.sessionExpireTime, permissions],
			function(error, queryResult){
				if (!!error)
				{
					callback(error, undefined);
				}
				else
				{
					callback(undefined, queryResult);
				}
			}
		);
	});*/
	async.waterfall([
			function (innerCallback) {
				crypto.pbkdf2(password, salt, 4096, 256, innerCallback);
			},
			function (hash, innerCallback) {
				exports.generateSessId(dbConnection, 20, function (error, result) {
					innerCallback(error, hash, result);
				});
			},
			function (hash, sessid, innerCallback) {
				dbConnection.query(
					'INSERT INTO `uniusers` '+
					'(`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) '+
					'VALUES '+
					'(?, ?, ?, ?, NOW(), NOW() + INTERVAL ? SECOND, '+
						'(SELECT `id` FROM `locations` WHERE `default` = 1), '+
					'?)',
					[user, salt, hash.toString(), sessid, config.sessionExpireTime,
						permissions],
					innerCallback);
			},
		],
		function (error, result) {
			callback(error, result);
		}
	);
};
