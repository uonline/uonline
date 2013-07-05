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
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


require_once('utils.php');

$HEAD = $BODY = '';

insertEncoding();

if ($_POST) {
	if ($_POST['pass'] === ADMIN_PASS) {

		if ($_POST['ignore']) {
			writeNewHash();
		}

		echo '<style>h4, h5, h6 { margin: 0px; } h5 { margin-left: 10px; } h6 { margin-left: 20px; } .err { color: red; } .warn { color: #95CE58; } td { border: solid 1px grey; } </style>';

		function ok() { global $done; $done++; return '<span>done</span>'; }
		function err() { global $err; $err++; return '<span class="err">error</span>'; }
		function warn($t = false) { global $warn; $warn++; return '<span class="warn">'.($t?$t:'exists').'</span>'; }

		if ($_POST['createbases']) {
			echo '<h4>Создание баз данных ... ';
			mysqlInit();
			echo mysql_errno()===0?ok():err();
			echo '</h4><br />';
		}
		else {
			echo '<h4>Подключение к базам данных...';
			mysqlConnect();
			echo mysql_errno()===0?ok():err();
			echo '</h4><br />';
		}

		if ($_POST['updatetables']) {

			$t = getNewTables();
			$c = getNewColumns();

			//creating tables
			foreach ($t as $k => $v) {
				echo '<h5>Создание таблицы `'.$k.'` ... ';
				$res = addTable($k, $v);
				echo $res === FALSE ? warn() : ($res === 0 ? ok() : err());
				echo '</h5>';
			}
			echo '<br />';
			//updating tables
			foreach ($c as $k => $v) {
				echo '<h5>Обновление таблицы '.$v['table'].' ...<h5>';
				//adding new columns
				if ($v['columns']) foreach ($v['columns'] as $v1) {
					$cn = explode("|", $v1);
					echo '<h6>Создание столбца `'.$cn[0].'` ... ';
					$res = addColumn($v['table'], $v1);
					echo $res === FALSE ? warn() : ($res === 0 ? ok() : err());
					echo '</h6>';
				}
				//renaming columns
				if ($v['rename']) foreach ($v['rename'] as $v1) {
					$cn = explode("|", $v1);
					echo "<h6>Переименование столбца `$cn[0]` в `$cn[1]` ... ";
					$res = renameColumn($v['table'], $v1);
					echo $res === FALSE ? warn('not exists') : ($res === 0 ? ok() : err());
					echo '</h6>';
				}
				//change columns
				if ($v['change']) foreach ($v['change'] as $v1) {
					$cn = explode("|", $v1);
					echo "<h6>Изменение столбца `$cn[0]` ... ";
					$res = changeColumn($v['table'], $v1);
					echo $res === FALSE ? warn('not exists') : ($res === 0 ? ok() : err());
					echo '</h6>';
				}
				//drop columns
				if ($v['drop']) foreach ($v['drop'] as $v1) {
					echo "<h6>Удаление столбца `$v1` ... ";
					$res = dropColumn($v['table'], $v1);
					echo $res === FALSE ? warn('not exists') : ($res === 0 ? ok() : err());
					echo '</h6>';
				}

			}
			echo '<br />';
			if (!$err) writeNewHash();
		}



		/********* filling areas and locations ***********/
		if($_POST['fillareas']) {
			echo '<h5>Создание локаций ... ';
			mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Лес', 1)");
			mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Замок', 2)");

			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Погреб', 'Выбраться на кухню=2', 'Большие бочки и запах плесени...', 1, 2, 1)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Кухня', 'Спуститься в погреб=1|Пройти в гостиную=3', 'Разрушенная печь и горшки...', 2, 2, 0)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Гостиная', 'Выбраться на кухню=2|Подняться на чердак=4|Убраться на опушку=6', 'Большой круглый стол, обставленный стульями, картины на стенах...', 3, 2, 0)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Чердак', 'Спуститься в гостиную=3', 'Много старинных вещей и пыли...', 4, 2, 0)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Берлога', 'Двигаться на опушку=6|Выбраться к реке=7', 'Много следов и обглоданные останки...', 5, 1, 0)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Опушка', 'Забраться в берлогу=5|Подняться к реке=7|Войти в замок=3', 'И тут мне надоело...', 6, 1, 0)");
			mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `area`, `default`) VALUES ('Река', 'Забраться в берлогу=5|Выйти на опушку=6', 'Прозрачная вода и каменистый берег...', 7, 1, 0)");
			echo (mysql_errno()===0?ok():err()).'</h5>';
			echo '<br />';
		}

		if($_POST['fillmonsters']) {
			echo '<h5>Создание монстров ... ';
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

			echo (mysql_errno()===0?ok():err()).'</h5>';
			echo '<br />';
		}
		/********* filling areas and locations ***********/

		if ($_POST['optimize']) {
			mysqlConnect();
			$q = mysql_query(
				"SELECT `TABLE_NAME` ".
				"FROM `information_schema`.`TABLES` ".
				"WHERE `TABLE_SCHEMA`='".MYSQL_BASE."'");
			while ($t = mysql_fetch_array($q)) {
				echo '<h5>Оптимизация таблицы `'.$t[0].'` ... ';
				$q1 = mysql_query("OPTIMIZE TABLE `$t[0]`");
				do $a = mysql_fetch_array($q1);
				while ($a && $a['Msg_type'] !== 'status');
				echo ($a && ($a['Msg_text'] === "OK" || !strcasecmp($a['Msg_text'],"up to date")) ? ok() : err() ).'</h5>';
			}
		}

		echo
			'<br /><h3>Ошибок: '.($err?('<span class="err">'.$err.'</span><style>body {background-color: #E6C5C5}</style>'):0).
			'<br />Предупреждений: '.($warn?$warn:0).
			'<br />Готово: '.($done?$done:0).'</h3>';

		}
	else {
		wrongPass();
		fofForm();
	}
}
else fofForm();

echo makePage($HEAD, $BODY);







function wrongPass() {
	global $BODY, $HEAD;
	$HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
	$BODY .= '<span style="color: red">Пароль неверный.</span><br/>';
}


function initResult() {
	global $BODY, $HEAD, $at, $ac, $_POST;
	if (!$at) $at = array(); if (!$ac) $ac = array();
	//$HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
	if (array_filter($at) || array_filter($ac) || $_POST['fillareas']) {
		$BODY .= 'Внесённые изменения: <br />';
		if (array_filter($at)) { $cre = ''; foreach (array_filter($at) as $k => $v) $cre .= '  <b>'.$k.'</b><br />'; $BODY .= '<pre>'.' Созданы таблицы:<br />'.$cre.'</pre><br />'; }
		if (array_filter($ac)) { $cre = ''; foreach (array_filter($ac) as $k => $v) $cre .= '  <b>'.$k.'</b><br />'; $BODY .= '<pre>'.' Добавлены столбцы:<br />'.$cre.'</pre><br />'; }
		if ($_POST['fillareas']) $BODY .= '<pre> Тестовые локации заполнены.</pre>';
	}
	else $BODY .= 'Изменений не внесено';
}

function fofForm() {
	global $BODY;
	$BODY .=
	'<form method="post" id="form" action="init.php">'.
	'<table style="border: 1px grey solid; border-collapse: collapse;">'.
	'<thead><tr><th colspan="2">Создание базы данных.</th></tr></thead>'.
	(getNewHash() !== getHash()?'<thead><tr><th colspan="2">Таблицы должны быть обновлены <input type="button" onclick="ignore.value=\'on\'; form.submit()" value="Игнорировать" /></th></tr></thead>':'').
	'<tr><td><input type="button" value="Отметить все" onclick="this.chk = !this.chk; this.value=this.chk?\'Снять все\':\'Отметить все\'; ch = function(v) { Array.prototype.forEach.call(document.getElementsByTagName(\'input\'), function(e) { e.checked = v; }); }; ch(this.chk);"/></td><td></td>'.
	'<tr><td>&nbsp;</td><td>&nbsp;</td>'.
	'<tr><td>Создавать базы:</td><td><input type="checkbox" name="createbases"/></td>'.
	'<tr><td>Обновлять таблицы:</td><td><input checked type="checkbox" name="updatetables"/></td>'.
	'<tr><td>&nbsp;</td><td>&nbsp;</td>'.
	'<tr><td>Заполнить тестовые локации:</td><td><input type="checkbox" name="fillareas"/></td>'.
	'<tr><td>Заполнить тестовых монстров:</td><td><input type="checkbox" name="fillmonsters"/></td>'.
	'<tr><td>&nbsp;</td><td>&nbsp;</td>'.
	'<tr><td>Оптимизация таблиц:</td><td><input type="checkbox" name="optimize"/></td>'.
	'<tr><td>&nbsp;</td><td>&nbsp;</td>'.
	'<tr><td>Административный пароль:</td><td><input name="pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'" /></td>'.
	'<input id="ignore" type="hidden" name="ignore"/>'.
	'</table>'.
	'<br /><input type="submit" value="Создать" /><br />';
}

?>
