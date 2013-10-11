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
			callback(error, error || (result.rows[0].result > 0));
		}
	);
};

exports.idExists = function(dbConnection, id, callback) {
	dbConnection.query(
		'SELECT count(*) FROM `uniusers` WHERE `id`= ?',
		[id],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			}
			else {
				callback(undefined, (result.rows[0].result > 0));
			}
		}
	);
};

exports.mailExists = function(dbConnection, mail, callback) {
	dbConnection.query(
		'SELECT count(*) FROM `uniusers` WHERE `mail` = ?',
		[mail],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			}
			else {
				callback(undefined, (result.rows[0].result > 0));
			}
		}
	);
};

exports.sessionExists = function(dbConnection, sess, callback) {
	dbConnection.query(
		'SELECT count(*) FROM `uniusers` WHERE `sessid` = ?',
		[sess],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			}
			else {
				callback(undefined, (result.rows[0].result > 0));
			}
		}
	);
};

exports.sessionInfoRefreshing = function(dbConnection, sessid, sess_timeexpire, callback) {
	if (!sessid)
	{
		callback(null, {sessionIsActive: false});
	}
	else
	{
		dbConnection.query(
			'SELECT user, permissions FROM uniusers WHERE sessid = ? AND sessexpire > NOW()',
			[sessid],
			function (error, result) {

				if (!!error) {
					callback(error, null);
					return;
				}

				if (result.rowCount === 0) {
					callback(null, {sessionIsActive: false});
					return;
				}

				exports.refreshSession(dbConnection, sessid, sess_timeexpire, function(err, res) {
					if (err) {callback(err, null); return;}
					callback(null, {
						sessionIsActive: true,
						username: result.rows[0].user,
						admin: (result.rows[0].permissions === 1)
					});
				});
			}
		);
	}
};

exports.generateSessId = function(dbConnection, sess_length, callback) {
	//here random sessid must be checked for uniqueness
	callback(undefined, exports.createSalt(sess_length));
};

exports.idBySession = function(dbConnection, sess, callback) {
	dbConnection.query(
		'SELECT `id` FROM `uniusers` WHERE `sessid` = ?',
		[sess],
		function (error, result) {
			if (!!error) {
				callback(error, undefined);
			}
			else {
				callback(undefined, result.rows[0].result);
			}
		}
	);
};

exports.refreshSession = function(dbConnection, sess, sess_timeexpire, callback) {
	if (!sess)
	{
		callback(undefined, 'Not refreshing: empty sessid');
	}
	else
	{
		dbConnection.query(
			'UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL ? SECOND WHERE `sessid` = ?',
			[sess_timeexpire, sess], callback);
	}
};

exports.closeSession = function(dbConnection, sess, callback) {
	if (!sess)
	{
		callback(undefined, 'Not closing: empty sessid');
	}
	else
	{
		dbConnection.query(
			'UPDATE `uniusers` SET `sessexpire` = NOW() - INTERVAL 1 SECOND WHERE `sessid` = ?',
			[sess], callback
		);
	}
};

exports.createSalt = function(sess_length) {
	var salt = '';
	var a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	for(var i=0; i<sess_length; i++) { salt += a[Math.floor(Math.random() * a.length)]; }
	return salt;
};

exports.registerUser = function(dbConnection, user, password, permissions, callback) {
	var salt = this.createSalt(16);
	/*crypto.pbkdf2(password, salt, 4096, 256, function(error, cryptedPassword){
		if (!!error) callback(error, undefined);
		dbConnection.query(
			'INSERT INTO `uniusers` '+
			'(`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) VALUES '+
			'(?, ?, ?, ?, NOW(), NOW() + INTERVAL ? SECOND, (SELECT `id` FROM `locations` WHERE `default` = 1), ?)',
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
			function(innerCallback){
				crypto.pbkdf2(password, salt, 4096, 256, innerCallback);
			},
			function(previousResult, innerCallback){
				dbConnection.query(
					'INSERT INTO `uniusers` '+
					'(`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) '+
					'VALUES '+
					'(?, ?, ?, ?, NOW(), NOW() + INTERVAL ? SECOND, '+
						'(SELECT `id` FROM `locations` WHERE `default` = 1), '+
					'?)',
					[user, salt, previousResult.toString(), exports.generateSessId(), config.sessionExpireTime,
						permissions],
					innerCallback);
			},
		],
		function(error, result){
			callback(error, result);
		}
	);
};
