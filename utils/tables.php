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

function tableExists($t) {
	mysqliConnect();
	return
		mysqlFirstRes(
			"SELECT count(*) ".
			"FROM INFORMATION_SCHEMA.TABLES ".
			"WHERE TABLE_SCHEMA='".MYSQL_BASE."' ".
			"AND TABLE_NAME='$t'");
}

function addTable($t, $o) {
	$mysqli = mysqliConnect();
	action('Creating table `'.$t.'` '.$o);
	if (!tableExists($t)) {
		$mysqli->query("CREATE TABLE `$t` $o");
		if ($mysqli->errno !== 0) {
			echo result('error');
		}
		else result('ok');
	}
	else result('exists');
}

function columnExists($t, $c) {
	mysqliConnect();
	return
		mysqlFirstRes(
			"SELECT count(*) ".
			"FROM INFORMATION_SCHEMA.COLUMNS ".
			"WHERE TABLE_SCHEMA='".MYSQL_BASE."' ".
			"AND TABLE_NAME='$t' AND COLUMN_NAME='$c'");
}

function addColumn($t, $o) {
	$mysqli = mysqliConnect();
	list($c, $o) = explode('|', $o);
	action('Creating column `'.$c.'` in table `'.$t.'`');
	if (!columnExists($t, $c)) {
		$mysqli->query("ALTER TABLE `$t` ADD COLUMN `$c` $o");
		if ($mysqli->errno !== 0) {
			result('error');
		}
		else result('ok');
	}
	else result('exists');
}

function renameColumn($t, $o) {
	$mysqli = mysqliConnect();
	list($oc, $nc) = explode('|', $o);
	if (!columnExists($t, $oc)) return FALSE;
	else {
		$type = mysqlFirstRes(
			"SELECT COLUMN_TYPE ".
			"FROM INFORMATION_SCHEMA.COLUMNS ".
			"WHERE TABLE_SCHEMA='".MYSQL_BASE."' ".
			"AND TABLE_NAME='$t' AND COLUMN_NAME='$oc'");
		$mysqli->query("ALTER TABLE `$t` CHANGE COLUMN `$oc` `$nc` $type");
		return $mysqli->errno;
	}
}

function changeColumn($t, $o) {
	$mysqli = mysqliConnect();
	list($oc, $nc) = explode('|', $o);
	if (!columnExists($t, $oc)) return FALSE;
	else {
		$mysqli->query("ALTER TABLE `$t` CHANGE COLUMN `$oc` `$oc` $nc");
		return $mysqli->errno;
	}
}

function dropColumn($t, $o) {
	$mysqli = mysqliConnect();
	if (!columnExists($t, $o)) return FALSE;
	else {
		$mysqli->query("ALTER TABLE `$t` DROP COLUMN `$o`");
		return $mysqli->errno;
	}
}

?>