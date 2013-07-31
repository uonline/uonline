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


require_once 'utils.php';

if(isset($argv)) {
	if (in_array("--database", $argv)) database ();
	if (in_array("--unify", $argv)) unify ();
	if (in_array("--optimize", $argv)) optimize ();
	if (in_array("--test-monsters", $argv)) testMonsters();
	if (in_array("--help", $argv)) echo help();
}
else echo help();

function database() {
	echo "Creating database `uonline`... ";
		$mysqli = mysqliInit();
		echo $mysqli && $mysqli->errno === 0 ? ok() : err();
		echo "\n";
	}
	if (in_array("--tables", $argv)) {
		echo 'Подключение к базам данных...';
		$mysqli = mysqliConnect();
		echo $mysqli && $mysqli->errno === 0 ? ok() : err();
		echo "\n";

		migrate(getNewestRevision());
}

function tables() {
	migrate(getNewestRevision());
}

function unify() {
	//
}

function optimize() {
	echo 'Подключение к базам данных...';
	$mysqli = mysqliConnect();
	echo $mysqli && $mysqli->errno === 0 ? ok() : err();
	echo "\n";

	$q = mysql_query(
			"SELECT `TABLE_NAME` ".
			"FROM `information_schema`.`TABLES` ".
			"WHERE `TABLE_SCHEMA`='".MYSQL_BASE."'");
	while ($t = mysql_fetch_array($q)) {
		echo 'Оптимизация таблицы `'.$t[0].'` ... ';
		$q1 = mysql_query("OPTIMIZE TABLE `$t[0]`");
		do $a = mysql_fetch_array($q1);
		while ($a && $a['Msg_type'] !== 'status');
		echo ($a && ($a['Msg_text'] === "OK" || !strcasecmp($a['Msg_text'],"up to date")) ? ok() : err() );
		echo "\n";
	}
}

function testMonsters() {
	echo 'Подключение к базам данных...';
	$mysqli = mysqliConnect();
	echo $mysqli && $mysqli->errno === 0 ? ok() : err();
	echo "\n";

	echo 'Создание монстров ... ';
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (1, 3, 723001325, 1, 1, NULL, 23)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (2, 2, 1054697917, 1, 1, NULL, 11)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (3, 3, 648737395, 1, 1, NULL, 22)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (4, 7, 845588419, 1, 1, NULL, 5)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (5, 5, 77716864, 1, 1, NULL, 16)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (6, 7, 889033849, 1, 1, NULL, 16)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (7, 4, 772635195, 1, 1, NULL, 13)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (8, 2, 77716864, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (9, 3, 889033849, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (10, 3, 578736465, 1, 1, NULL, 10)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (11, 2, 774449300, 1, 1, NULL, 9)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (12, 2, 701741103, 1, 1, NULL, 18)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (13, 1, 288482442, 1, 1, NULL, 18)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (14, 4, 845588419, 1, 1, NULL, 6)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (15, 2, 451777421, 1, 1, NULL, 5)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (16, 5, 772635195, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (17, 3, 851644277, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (18, 3, 29958182, 1, 1, NULL, 15)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (19, 4, 889033849, 1, 1, NULL, 23)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (20, 5, 772635195, 1, 1, NULL, 17)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (21, 6, 648737395, 1, 1, NULL, 18)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (22, 4, 29958182, 1, 1, NULL, 8)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (23, 7, 29958182, 1, 1, NULL, 18)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (24, 4, 571597042, 1, 1, NULL, 22)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (25, 6, 904434466, 1, 1, NULL, 22)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (26, 4, 904434466, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (27, 1, 1054697917, 1, 1, NULL, 21)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (28, 5, 833637588, 1, 1, NULL, 16)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (29, 3, 569902394, 1, 1, NULL, 25)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (30, 7, 701741103, 1, 1, NULL, 20)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (31, 4, 172926385, 1, 1, NULL, 6)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (32, 2, 851644277, 1, 1, NULL, 19)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (33, 7, 569902394, 1, 1, NULL, 13)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (34, 3, 889033849, 1, 1, NULL, 6)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (35, 1, 723001325, 1, 1, NULL, 24)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (36, 2, 288482442, 1, 1, NULL, 10)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (37, 2, 77716864, 1, 1, NULL, 25)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (38, 2, 889033849, 1, 1, NULL, 14)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (39, 3, 889033849, 1, 1, NULL, 7)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (40, 1, 648737395, 1, 1, NULL, 5)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (41, 5, 569902394, 1, 1, NULL, 24)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (42, 4, 744906885, 1, 1, NULL, 22)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (43, 3, 29958182, 1, 1, NULL, 13)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (44, 5, 77716864, 1, 1, NULL, 24)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (45, 3, 77716864, 1, 1, NULL, 6)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (46, 1, 772635195, 1, 1, NULL, 13)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (47, 2, 889033849, 1, 1, NULL, 5)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (48, 5, 571597042, 1, 1, NULL, 11)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (49, 5, 569902394, 1, 1, NULL, 18)");
	$mysqli->query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (50, 1, 772635195, 1, 1, NULL, 13)");
	
	echo $mysqli && $mysqli->errno === 0 ? ok() : err();
	echo "\n";
}


function help() {
	return
		" [--database] [--tables] [--unify] [--optimize] [--test-monsters]";
}

function ok() { global $done; $done++; return 'done'; }
function err() { global $err; $err++; return 'error'; }
function warn($t = false) { global $warn; $warn++; return ($t?$t:'exists'); }

?>
