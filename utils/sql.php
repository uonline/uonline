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


$MYSQLI_CONN = null;

function mysqliInit($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE)  {
	if (!isset($MYSQLI_CONN)) $MYSQLI_CONN = mysqli_connect($host, $user, $pass);
	$MYSQLI_CONN->query('CREATE DATABASE IF NOT EXISTS `'.$base.'`');
	$MYSQLI_CONN->select_db($base);
	return $MYSQLI_CONN;
}

function mysqliConnect($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {
	global $MYSQLI_CONN;
	if (!isset($MYSQLI_CONN)) $MYSQLI_CONN = mysqli_connect($host, $user, $pass);
	$MYSQLI_CONN->select_db($base);
	return $MYSQLI_CONN;
}

function mysqlDelete() {
	mysqliConnect()->query('DROP DATABASE '.MYSQL_BASE);
}

function mysqlFirstRes($query) {
	global $MYSQLI_CONN;
	$q = $MYSQLI_CONN->query($query);
	if (!$q) return false;
	$a = $q->fetch_array();
	return ($v = $a[0]) ? $v : false;
}

function mysqlFirstRow($query) {
	global $MYSQLI_CONN;
	$q = $MYSQLI_CONN->query($query);
	if (!$q) return false;
	$a = $q->fetch_assoc();
	return $a;
}

?>
