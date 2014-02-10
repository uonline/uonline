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


function rightSess($s) {
	return $s && strlen($s) == SESSION_LENGTH;
}

function idExists($id) {
	if (correctId($id)) {
		mysqliConnect();
		return mysqlFirstRes(
			'SELECT count(*) '.
			'FROM `uniusers` '.
			'WHERE `id`="'.fixId($id).'"');
	}
}

function userExists($user) {
	if (correctUserName($user)) {
		mysqliConnect();
		return
			!!mysqlFirstRes(
				'SELECT count(*) '.
				'FROM `uniusers` '.
				'WHERE `user`="'.$user.'"');
	}
}

function mailExists($mail) {
	mysqliConnect();
	return
		mysqlFirstRes(
			'SELECT * '.
			'FROM `uniusers` '.
			'WHERE `mail`="'.$mail.'"');
}

function sessionExists($s) {
	if (rightSess($s)) {
		mysqliConnect();
		return
			mysqlFirstRes(
				'SELECT count(*) '.
				'FROM `uniusers` '.
				'WHERE `sessid`="'.$s.'"');
	}
}

function sessionActive($s) {
	if (rightSess($s)) {
		mysqliConnect();
		return
			mysqlFirstRes(
				'SELECT `sessexpire` > NOW() '.
				'FROM `uniusers` '.
				'WHERE `sessid`="'.$s.'"');
	}
}

function sessionExpired($sess) {
	return !sessionActive($sess);
}

function generateSessId() {
	mysqliConnect();
	while (mysqlFirstRes(
		'SELECT count(*) '.
		'FROM `uniusers` '.
		'WHERE `sessid`="'.($sessid = mySalt()).'"') );
	return $sessid;
}

function userBySession($s) {
	if (rightSess($s)) {
		mysqliConnect();
		return
			mysqlFirstRes(
				'SELECT `user` '.
				'FROM `uniusers` '.
				'WHERE `sessid`="'.$s.'"');
	}
}

function idBySession($s) {
	if (rightSess($s)) {
		mysqliConnect();
		return
			mysqlFirstRes(
				'SELECT `id` '.
				'FROM `uniusers` '.
				'WHERE `sessid`="'.$s.'"');
	}
}

function refreshSession($s) {
	global $MYSQLI_CONN;
	if (rightSess($s)) {
		mysqliConnect();
		if (sessionActive($s))
			$MYSQLI_CONN->query(
				'UPDATE `uniusers` '.
				'SET `sessexpire` = NOW() + INTERVAL '.SESSION_TIMEEXPIRE.' SECOND '.
				'WHERE `sessid`="' . $s . '"');
	}
}

function closeSession($s) {
	global $MYSQLI_CONN;
	if (rightSess($s)) {
		mysqliConnect();
		$MYSQLI_CONN->query(
			'UPDATE `uniusers` '.
			'SET `sessexpire` = NOW() - INTERVAL 1 SECOND '.
			'WHERE `sessid`="' . $s . '"');
	}
}
function mySalt($l = SESSION_LENGTH) {
	$salt = '';
	$a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	for($i=0; $i<$l; $i++) { $salt.=$a[rand(0,strlen($a)-1)]; }
	return $salt;
}

function registerUser($u, $p, $perm = 0) {
	global $MYSQLI_CONN;
	$salt = mySalt(16);
	$session = generateSessId();
	$MYSQLI_CONN->query(
		'INSERT INTO `uniusers` '.
		'(`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) VALUES '.
		'("'.$u.'", "'.$salt.'", "'.myCrypt($p, $salt).'", "'.$session.'", NOW(), NOW() + INTERVAL '.SESSION_TIMEEXPIRE.' SECOND, '.defaultLocation().', '.$perm.')');
	return $session;
}

function validPassword($u, $p) {
	mysqliConnect();
	$q = mysqlFirstRow('SELECT `hash`, `salt` FROM `uniusers` WHERE `user`="'.$u.'"');
	return $q['hash'] == myCrypt($p, $q['salt']);
}
function accessGranted($u, $p) {
	return correctUserName($u) && correctPassword($p) && userExists($u) && validPassword($u, $p);
}

function allowToRegister($u, $p) {
	return correctUserName($u) && correctPassword($p) && !userExists($u);
}

function setMyCookie($n, $v, $exp = null, $path = '/', $domain = null, $secure = null, $httponly = null) {
	if (!$exp) $exp = time() + SESSION_TIMEEXPIRE;
	setcookie($n, $v, $exp, $path, $domain, $secure, $httponly);
}

function userPermissions($s) {
	if (rightSess($s)) {
		mysqliConnect();
		return mysqlFirstRes(
			'SELECT `permissions` '.
			'FROM `uniusers` '.
			"WHERE `sessid`='$s'");
	}
}

function fileFromPath($p) {
	if (preg_match('/[^\\\\\\/]+$/', $p, $res)) return $res[0];
}

function setSession($u) {
	global $MYSQLI_CONN;
	mysqliConnect();
	$s = generateSessId();
	$MYSQLI_CONN->query(
		'UPDATE `uniusers` '.
		'SET `sessexpire` = NOW() + INTERVAL '.SESSION_TIMEEXPIRE.' SECOND, '.
		'`sessid`="'.$s.'" '.
		'WHERE `user`="'.$u.'"');
	return $s;
}

?>
