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
		mysqlInit();
		echo mysql_errno()===0?ok():err();
		echo "\n";
	}
	if (in_array("--tables", $argv)) {
		echo 'Подключение к базам данных...';
		mysqlConnect();
		echo mysql_errno()===0?ok():err();
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
	mysqlConnect();
	echo mysql_errno()===0?ok():err();
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
	mysqlConnect();
	echo mysql_errno()===0?ok():err();
	echo "\n";

	echo 'Создание монстров ... ';
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (1, 'Гигантская улитка', 1, 1, 1, 1, 1, 1, 1, 1, 3)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (2, 'Червь-хищник', 2, 1, 2, 2, 1, 1, 2, 1, 1)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (3, 'Ядовитая многоножка', 1, 1, 2, 1, 1, 1, 1, 1, 1)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (4, 'Скорпион', 1, 2, 1, 1, 1, 1, 1, 1, 1)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (5, 'Кобра', 2, 1, 3, 1, 3, 2, 1, 2, 1)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (6, 'Дикий кабан', 1, 2, 1, 2, 1, 1, 1, 2, 1)");
	mysql_query("REPLACE INTO `monster_prototypes` (`id`, `name`, `level`, `power`, `agility`, `endurance`, `intelligence`, `wisdom`, `volition`, `health_max`, `mana_max`) VALUES (7, 'Тарантул', 3, 1, 4, 2, 1, 2, 4, 1, 1)");

	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (1, 2, 1, 1, 1, NULL, 5)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (2, 2, 6, 1, 1, NULL, 13)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (3, 3, 2, 1, 1, NULL, 7)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (4, 4, 5, 1, 1, NULL, 11)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (5, 5, 5, 1, 1, NULL, 12)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (6, 5, 1, 1, 1, NULL, 6)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (7, 5, 6, 1, 1, NULL, 14)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (8, 7, 3, 1, 1, NULL, 8)");
	mysql_query("REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (9, 7, 4, 1, 1, NULL, 9)");

	echo (mysql_errno()===0?ok():err());
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
