<?php


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


function correctUserName($nick) {
	return
		strlen($nick)>1 &&
		strlen($nick)<=32 &&
		!preg_match('/[^a-zA-Z0-9а-яА-ЯёЁйЙру_\\- ]/', $nick);
}

function correctMail($mail) {
	return
		preg_match('/([a-z0-9_\.\-]{1,20})@([a-z0-9\.\-]{1,20})\.([a-z]{2,4})/is', $mail, $res) &&
		$mail == $res[0];
}

function correctPassword($pass) {
	return
		strlen($pass)>3 &&
		strlen($pass)<=32 &&
		preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
		$pass == $res[0];
}

function correctId($id) {
	return $id+0 > 0;
}

function fixId($id) {
	return $id+0;
}

?>
