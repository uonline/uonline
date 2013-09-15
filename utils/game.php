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


function defaultLocation() {
	mysqliConnect();
	return (int) mysqlFirstRes(
		'SELECT `id` '.
		'FROM `locations` '.
		'WHERE `default`=1');
}

function userLocationId($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `location` '.
		'FROM `uniusers` '.
		'WHERE `sessid`="'.$s.'"');
}

function userAreaId($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `locations`.`area` '.
		'FROM `locations`,`uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s'".
		'AND `locations`.`id`= `uniusers`.`location`');

}

function currentLocationTitle($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `locations`.`title` '.
		'FROM `locations`,`uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s'".
		'AND `locations`.`id`= `uniusers`.`location`');
}

function currentLocationPicture($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `locations`.`picture` '.
		'FROM `locations`,`uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s'".
		'AND `locations`.`id`= `uniusers`.`location`');
}

function currentAreaTitle($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `areas`.`title` '.
		'FROM `areas`,`locations`,`uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s'".
		'AND `locations`.`id`= `uniusers`.`location`'.
		'AND `areas`.`id` = `locations`.`area`');
}

function currentLocationDescription($s) {
	mysqliConnect();
	return mysqlFirstRes(
		'SELECT `description` '.
		'FROM `locations`, `uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s'".
		'AND `locations`.`id` = `uniusers`.`location`');
}

function allowedZones($s, $idsonly = false) {
	$goto = mysqlFirstRes(
		'SELECT `locations`.`goto` '.
		'FROM `locations`, `uniusers` '.
		"WHERE `uniusers`.`sessid` = '$s' ".
		'AND `locations`.`id` = `uniusers`.`location` '.
		'AND `uniusers`.`fight_mode` = 0');
	$a = array(); $i = 0;
	if (!$goto) return $a;
	foreach (explode('|', $goto) as $v) {
		$la = explode('=', $v);
		$a[$i++] = $idsonly ? $la[1] : array ('to' => $la[1], 'name' => $la[0]);
	}
	return $a;
}

function changeLocation($s, $lid) {
	global $MYSQLI_CONN;
	mysqliConnect();
	if (in_array( $lid, allowedZones($s, true) ) ) {
		$MYSQLI_CONN->query(
			"UPDATE `uniusers` ".
			"SET `location` = '$lid' ".
			"WHERE `sessid`='$s'");
		$attack_chance = mysqlFirstRes(
			"SELECT max(`attack_chance`) ".
			"FROM `monsters`, `uniusers` ".
			"WHERE `uniusers`.`sessid` = '$s' ".
			"AND `uniusers`.`location` = `monsters`.`location`");
		if (rand(1,100)<=$attack_chance) $MYSQLI_CONN->query(
			"UPDATE `uniusers` ".
			"SET `autoinvolved_fm` = 1, ".
			"`fight_mode` = 1 ".
			"WHERE `sessid` = '$s'");
		return true;
	}
	else return false;
}

function goAttack($s) {
	global $MYSQLI_CONN;
	$MYSQLI_CONN->query(
		"UPDATE `uniusers` ".
		"SET `fight_mode` = 1 ".
		"WHERE `sessid`='$s'");
}

function goEscape($s) {
	global $MYSQLI_CONN;
	$MYSQLI_CONN->query(
		"UPDATE `uniusers` ".
		"SET `fight_mode` = 0, `autoinvolved_fm` = 0 ".
		"WHERE `sessid`='$s'");
}

function usersOnLocation($s) {
	global $MYSQLI_CONN;
	$q = $MYSQLI_CONN->query(
		'SELECT `user`, `id` '.
		'FROM `uniusers` '.
		'WHERE `sessexpire` > NOW() '.
		'AND `location`='.userLocationId($s).' AND `sessid` != "'.$s.'"' );
	for ($a=array(), $i=0; $q && $r = $q->fetch_assoc(); $a[$i++]=array(id => $r['id'], name => $r['user']) );
	return $a;
}

function monstersOnLocation($s) {
	global $MYSQLI_CONN;
	$q = $MYSQLI_CONN->query(
		'SELECT `monster_prototypes`.*, `monsters`.*'.
		'FROM `monster_prototypes`, `monsters`'.
		'WHERE `monsters`.`location`=(select `uniusers`.`location` from `uniusers` where `sessexpire` > NOW() AND `uniusers`.`sessid`="'.$s.'")'.
		'AND `monster_prototypes`.`id` = `monsters`.`id`');
	for ($a=array(), $i=0; $q && $r = $q->fetch_assoc(); $a[$i++]=array('id' => $r['id'], 'name' => $r['name']) );
	return $a;
}

function fightMode($s, $e) {
	global $MYSQLI_CONN;
	$q = mysqlFirstRes(
		"SELECT `$e` ".
		'FROM `uniusers` '.
		"WHERE `sessid` = '$s'" );
	if ($e === 'autoinvolved_fm') $MYSQLI_CONN->query(
		"UPDATE `uniusers` ".
		"SET `autoinvolved_fm` = 0 ".
		"WHERE `sessid`='$s'");
	return $q;
}

function characters() {
	return array(
		'health',
		'health_max',
		'mana',
		'mana_max',
		'energy',
		'power',
		'defense',
		'agility',
		'accuracy',
		'intelligence',
		'initiative',
		'exp',
		'level',
		);
}

function userCharacters($p, $t = 'sess') {

	switch ($t) {
		case 'id':
			if (!idExists($p)) return;
			mysqliConnect();
			$q = mysqlFirstRow('SELECT * FROM `uniusers` WHERE `id`="'.$p.'"');
			break;
		case 'user':
			if (!userExists($p)) return;
			mysqliConnect();
			$q = mysqlFirstRow('SELECT * FROM `uniusers` WHERE `user`="'.$p.'"');
			break;
		case 'sess':
			if (!rightSess($p)) return;
			mysqliConnect();
			$q = mysqlFirstRow('SELECT * FROM `uniusers` WHERE `sessid`="'.$p.'"');
			break;
	}
	$cl = characters();
	foreach ($cl as $v) $ar[$v] = $q[$v];

	$ar['health_percent'] = $ar['health'] * 100 / $ar['health_max'];
	$ar['mana_percent'] = $ar['mana'] * 100 / $ar['mana_max'];

	$exp_prev_max = ap(EXP_MAX_START, $ar['level']-1, EXP_STEP);

	$ar['exp_max'] = ap(EXP_MAX_START, $ar['level'], EXP_STEP);
	$ar['exp_percent'] = ($ar['exp']-$exp_prev_max) * 100 / ($ar['exp_max']-$exp_prev_max);

	$ar['nickname'] = $q['user'];
	$ar['id'] = $q['id'];

	return $ar;
}

?>
