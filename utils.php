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


require_once('config.php');

$MYSQLI_CONN = null;
/*********************** maintain base in topical state *********************************/
function mysqliInit($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE)  {
	if (!isset($MYSQLI_CONN)) $MYSQLI_CONN = mysqli_connect($host, $user, $pass);
	$MYSQLI_CONN->query('CREATE DATABASE IF NOT EXISTS `'.$base.'`');
	$MYSQLI_CONN->select_db($base);
	return $MYSQLI_CONN;
}

/***** table functions *****/
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

/***** table functions *****/

/***** column functions *****/
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

/***** column functions *****/

function getMigrationFunctions() {
	return array (
		1 => function() {
			/************** uniusers ****************/
			addTable('uniusers', '(`id` INT AUTO_INCREMENT, PRIMARY KEY (`id`))');
			addColumn("uniusers", "location|INT DEFAULT 1");
			addColumn("uniusers", "permissions|INT DEFAULT 0");
			addColumn("uniusers", "user|TINYTEXT");
			addColumn("uniusers", "mail|TINYTEXT");
			addColumn("uniusers", "salt|TINYTEXT");
			addColumn("uniusers", "hash|TINYTEXT");
			addColumn("uniusers", "sessid|TINYTEXT");
			addColumn("uniusers", "sessexpire|DATETIME");
			addColumn("uniusers", "reg_time|DATETIME");

			addColumn("uniusers", "fight_mode|INT DEFAULT 0");
			addColumn("uniusers", "autoinvolved_fm|INT DEFAULT 0");
			addColumn("uniusers", "level|INT DEFAULT 1");
			addColumn("uniusers", "health|INT DEFAULT 200");
			addColumn("uniusers", "health_max|INT DEFAULT 200");
			addColumn("uniusers", "mana|INT DEFAULT 100");
			addColumn("uniusers", "mana_max|INT DEFAULT 100");
			addColumn("uniusers", "energy|INT DEFAULT 50");
			addColumn("uniusers", "power|INT DEFAULT 3");
			addColumn("uniusers", "defense|INT DEFAULT 3");
			addColumn("uniusers", "agility|INT DEFAULT 3"); //ловкость
			addColumn("uniusers", "accuracy|INT DEFAULT 3"); //точность
			addColumn("uniusers", "intelligence|INT DEFAULT 5"); //интеллект
			addColumn("uniusers", "initiative|INT DEFAULT 5"); //инициатива
			addColumn("uniusers", "exp|INT DEFAULT 0");
			addColumn("uniusers", "effects|TEXT");

			/************** locations ****************/
			addTable('locations', '(`id` INT, PRIMARY KEY (`id`))');
			addColumn("locations", "title|TINYTEXT");
			addColumn("locations", "goto|TINYTEXT");
			addColumn("locations", "description|TEXT");
			addColumn("locations", "area|INT");
			addColumn("locations", "picture|TINYTEXT");
			addColumn("locations", "default|TINYINT(1) DEFAULT 0");

			/************** areas ****************/
			addTable('areas', '(`id` INT, PRIMARY KEY (`id`))');
			addColumn("areas", "title|TINYTEXT");
			addColumn("areas", "description|TEXT");

			/************** monster_prototypes ****************/
			addTable('monster_prototypes', '(`id` INT AUTO_INCREMENT, PRIMARY KEY (`id`))');
			addColumn("monster_prototypes", "name|TINYTEXT");
			addColumn("monster_prototypes", "level|INT");
			addColumn("monster_prototypes", "power|INT");
			addColumn("monster_prototypes", "agility|INT");
			addColumn("monster_prototypes", "endurance|INT");
			addColumn("monster_prototypes", "intelligence|INT");
			addColumn("monster_prototypes", "wisdom|INT");
			addColumn("monster_prototypes", "volition|INT");
			addColumn("monster_prototypes", "health_max|INT");
			addColumn("monster_prototypes", "mana_max|INT");

			/************** monsters ****************/
			addTable('monsters', '(`incarn_id` INT AUTO_INCREMENT, PRIMARY KEY (`incarn_id`))');
			addColumn("monsters", "id|INT");
			addColumn("monsters", "location|INT");
			addColumn("monsters", "health|INT");
			addColumn("monsters", "mana|INT");
			addColumn("monsters", "effects|TEXT");
			addColumn("monsters", "attack_chance|INT");
		},
		2 => function() {
			/************** stats ****************/
			addTable('stats', '(`time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
			addColumn("stats", "gen_time|DOUBLE");
			addColumn("stats", "instance|TINYTEXT");
			addColumn("stats", "ip|TINYTEXT");
			addColumn("stats", "uagent|TINYTEXT");
			addColumn("stats", "url|TEXT");
		},
	);
}

function getNewestRevision() {
	$migrate = getMigrationFunctions();
	return max(array_keys($migrate));
}

function getCurrentRevision() {
	$r = file_exists('tablestate') ? trim(file_get_contents('tablestate')) : false;
	return (is_numeric($r) ? (int) $r : 0);
}

function setRevision($r) {
	$fp = fopen ("tablestate","w"); //открытие
	fputs($fp , $r ); //работа с файлом
	fclose ($fp); //закрытие
}

function migrate($revision) {
	$migrate = getMigrationFunctions();
	$currentRevision = getCurrentRevision(); // если файла-индекса не существует или в нём нет единственного числа, то 0
	if ($currentRevision < $revision)
	{
		foreach($migrate as $k => $v)
		{
			if ($k > $currentRevision)
			{
				section('Migrating from revision '.getCurrentRevision().' to '.$k);
				$v();
				setRevision($k);
				endSection();
			}
		}
	}
	else
	{
		writeln("Refused to migrate from revision {$currentRevision} to {$revision}.");
		return true;
	}
}

/*********************** maintain base in topical state *********************************/

function isAssoc($a) {
	if (array_keys($a) === range(0, count($a) - 1)) return false;
	return true;
}

function mysqlDelete() {
	mysqliConnect()->query('DROP DATABASE '.MYSQL_BASE);
}

function mysqliConnect($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {
	global $MYSQLI_CONN;
	if (!isset($MYSQLI_CONN)) $MYSQLI_CONN = mysqli_connect($host, $user, $pass);
	$MYSQLI_CONN->select_db($base);
	return $MYSQLI_CONN;
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
		'WHERE `sessid`="'.($sessid = mySalt()).'"') ); //were very idiotic..
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


/************************* GAME ***************************/
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
	for ($a=array(), $i=0; $q && $r = $q->fetch_assoc(); $a[$i++]=array(id => $r['id'], name => $r['name']) );
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
/************************* GAME ***************************/


/************************* statistics ***************************/
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
/************************* statistics ***************************/
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





require_once './yoficator/ReflectionTypeHint.php';
require_once './yoficator/UTF8.php';
require_once './yoficator/Text/Yoficator.php';
$yoficator = null;
function yof($s)
{
	global $yoficator;
	if ($yoficator === null) $yoficator = new Text_Yoficator();
	return $yoficator->parse($s);
}


function tf($s) {
	$s = preg_replace('/^-(?= )|(?<= )-(?= )|---/', '&mdash;', $s); // em dash is "---" or " - "
	$s = preg_replace('/--/', '&ndash;', $s); // en dash is "--"
	$s = preg_replace('/(?:(?<=\D\d\d\d\d)|(?<=^\d\d\d\d))-(?:(?=\d\d\d\d\D)|(?=\d\d\d\d$))/', '&ndash;', $s); // en dash in year ranges, like "1941-1945"
	$s = preg_replace('/(?:^|(?<=(?:\d|\s)))-(?=\d)/', "&minus;", $s); // minus in negative numbers like "-2" and math expressions like "24-11=13"
	$s = preg_replace('/(?:"|\&quot\;)(?=[a-zA-Zа-яА-ЯйЙёЁру0-9])/', '&laquo;', $s);
	$s = preg_replace('/(?<=[a-zA-Zа-яА-ЯйЙёЁру0-9])(?:"|\&quot\;)/', '&raquo;', $s);
	return $s;
}

function nl2p($s) {
	$ar = explode("\n\n", $s);
	for ($s='', $i=0; $i<count($ar); $s.='<p>'.$ar[$i].'</p>', $i++);
	return $s;
}

function ap($a1, $n, $step) {
	return (2 * $a1 + ($n-1) * $step) * $n / 2;
}

##SHA-512
function myCrypt($pass, $salt) {
	return crypt($pass, '$6$rounds=10000$'.$salt.'$');
}

##filtering array by array-mask
function array_filter_($a, $m) {
	$r = array();
	foreach ($m as $i=>$v ) { if($v) $r[$i]=$a[$i]; }
	return $r;
}

function b64UrlEncode($i) {
 return strtr(base64_encode($i), '+/=', '-_,');
}

function b64UrlDecode($i) {
 return base64_decode(strtr($i, '-_,', '+/='));
}

/********************** Text functions **********************/
$offset = 0;

function spaces($count)
{
	$s = '';
	for ($i=0; $i<$count; $i++) $s .= ' ';
	return $s;
}

function writeln($text)
{
	global $offset;
	echo spaces($offset).$text."\n";
}

function section($name)
{
	writeln($name.'...');
	global $offset;
	$offset += 2;
}

function endSection()
{
	global $offset;
	$offset -= 2;
}

function action($name)
{
	global $offset;
	echo spaces($offset).$name.'...';
}

function result($result)
{
	echo ' '.$result."\n";
}

?>
