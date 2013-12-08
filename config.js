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

exports.DATABASE_URL = process.env.DATABASE_URL ||
	'postgres://anonymous:nopassword@localhost/uonline';
exports.DATABASE_URL_TEST = process.env.DATABASE_URL_TEST ||
	'postgres://anonymous:nopassword@localhost/uonline_test';
exports.MYSQL_DATABASE_URL = process.env.MYSQL_DATABASE_URL ||
	'mysql://anonymous:nopassword@localhost/uonline';
exports.MYSQL_DATABASE_URL_TEST = process.env.MYSQL_DATABASE_URL_TEST ||
	'mysql://anonymous:nopassword@localhost/uonline_test';

/*
exports.MYSQL_URL = exports.MYSQL_DATABASE_URL.match(/.+\//)[0];
exports.MYSQL_DATABASE_NAME = exports.MYSQL_DATABASE_URL.match(/[^\/]+$/)[0];
exports.MYSQL_URL_TEST = exports.MYSQL_DATABASE_URL_TEST.match(/.+\//)[0];
exports.MYSQL_DATABASE_NAME_TEST = exports.MYSQL_DATABASE_URL_TEST.match(/[^\/]+$/)[0];
*/

exports.sessionLength = 64;
exports.sessionExpireTime = 3600; // seconds

exports.defaultInstanceForGuests = '/about/';
exports.defaultInstanceForUsers = '/game/';

exports.expStart = 1000;
exports.expStep = 1000;

exports.PERMISSIONS_USER = 0;
exports.PERMISSIONS_ADMIN = 65535;

exports.EXP_STEP = 1000;
exports.EXP_MAX_START = 1000;

