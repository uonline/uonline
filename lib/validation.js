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

exports.usernameIsValid = function(nick) {
	return (!!nick) && ( /^[a-zA-Z0-9а-яА-ЯёЁйЙру -]{2,32}$/ ).test(nick);
};

exports.emailIsValid = function(email) {
	return (!!email) && ( /^([a-z0-9_\.\-]{1,20})@([a-z0-9\.\-]{1,20})\.([a-z]{2,4})$/i ).test(email);
};

exports.passwordIsValid = function(pass) {
	return (!!pass) && ( /^[-!@#$%^&*()_+A-Za-z0-9 ]{4,32}$/ ).test(pass);
};
