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


function stats($gen_time) {
	global $_SERVER, $MYSQLI_CONN;
	$ua = addslashes($_SERVER['HTTP_USER_AGENT']);
	$url = addslashes($_SERVER['REQUEST_URI']);
	mysqliConnect();
	$MYSQLI_CONN->query(
		"INSERT INTO `stats` ".
		"(`gen_time`, `ip`, `uagent`, `url`) ".
		"VALUES ($gen_time, '$_SERVER[REMOTE_ADDR]', '$ua', '$url')");
}

function getStatistics() {
	global $MYSQLI_CONN;
	mysqliConnect();
	$q = $MYSQLI_CONN->query(
		"SELECT `gen_time` ".
		"FROM `stats` ".
		"WHERE `time` > NOW() - INTERVAL 24 HOUR");
	for ($a=array(), $i=0; $q && $r = $q->fetch_assoc(); $a[$i++] = $r['gen_time'] );
	return $a;
}

?>
