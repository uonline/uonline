<?php

require_once('config.php');


function mysqlInit($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE)  {
   defined("MYSQL_CONN") || define ("MYSQL_CONN", mysql_connect($host, $user, $pass) );
   mysql_query('CREATE DATABASE IF NOT EXISTS `'.$base.'`');
   mysql_select_db($base);
   mysql_query('CREATE TABLE IF NOT EXISTS `uniusers` (`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` DATETIME, `reg_time` DATETIME, `id` INT AUTO_INCREMENT, `location` INT DEFAULT 1, `permissions` INT DEFAULT 0, PRIMARY KEY  (`id`) )');

   /********** areas and locations **********/
   mysql_query('CREATE TABLE IF NOT EXISTS `locations` (`title` TINYTEXT, `goto` TINYTEXT, `description` TINYTEXT, `id` INT, `super` INT, `default` TINYINT(1) DEFAULT 0, PRIMARY KEY (`id`))');
   mysql_query('CREATE TABLE IF NOT EXISTS `areas` (`title` TINYTEXT, `id` INT, PRIMARY KEY (`id`))');
   /********** areas and locations **********/

   /********* add new columns ***********/
   mysql_query("ALTER TABLE `uniusers` ADD COLUMN `location` INT DEFAULT 3 AFTER `id`");
   mysql_query("ALTER TABLE `uniusers` ADD COLUMN `permissions` INT AFTER `location`");
   /********* add new columns ***********/

   /********* filling areas and locations ***********/
   mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Лес', 1)");
   mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Замок', 2)");
   
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Погреб', 'Выбраться на кухню=2', 'Большие бочки и запах плесени...', 1, 2, 1)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Кухня', 'Спуститься в погреб=1|Пройти в гостиную=3', 'Разрушенная печь и горшки...', 2, 2, 0)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('гостиная', 'Выбраться на кухню=2|Подняться на чердак=4|Убраться на опушку=6', 'Большой круглый стол, обставленный стульями, картины на стенах...', 3, 2, 0)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Чердак', 'Спуститься в гостиную=3', 'Много старинных вещей и пыли...', 4, 2, 0)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Берлога', 'Двигаться на опушку=6|Выбраться к реке=7', 'Много следов и обглоданные останки...', 5, 1, 0)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Опушка', 'Забраться в берлогу=5|Подняться к реке=7|Войти в замок=3', 'И тут мне надоело...', 6, 1, 0)");
   mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Река', 'Забраться в берлогу=5|Выйти на опушку=6', 'Прозрачная вода и каменистый берег...', 7, 1, 0)");
   /********* filling areas and locations ***********/
}

function mysqlDelete() {
   mysqlConnect();
   mysql_query('DROP DATABASE '.MYSQL_BASE);
}

function mysqlConnect($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {
   defined("MYSQL_CONN") || (define ("MYSQL_CONN", mysql_connect($host, $user, $pass) ) && mysql_select_db($base));
}

function mysqlBool($query) {
   $a = mysql_fetch_array(mysql_query($query));
   return !!$a[0];
}

function userExists($user) {
   mysqlConnect();
   return mysql_num_rows(mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$user.'"'));
}

function mailExists($mail) {
   mysqlConnect();
   return mysql_num_rows(mysql_query('SELECT * FROM `uniusers` WHERE `mail`="'.$mail.'"'));
}

function sessionExists($sess) {
   mysqlConnect();
   return mysql_num_rows(mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sess.'"'));
}

function sessionActive($sess) {
   mysqlConnect();
   return mysqlBool('SELECT `sessexpire` > NOW() FROM `uniusers` WHERE `sessid`="'.$sess.'"');
}

function sessionExpired($sess) {
   return !sessionActive($sess);
}

function sessionExpire($sess) {
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sess.'"') );
   return $a['sessexpire'];
}

function generateSessId() {
   mysqlConnect();
   do $sessid = mySalt(64);
   while ( mysql_fetch_array ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sessid.'"') ) );
   return $sessid;
}

function userBySession($sess) {
   mysqlConnect();
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sess.'"') );
   return $a['user'];
}

function idBySession($sess) {
   mysqlConnect();
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sess.'"') );
   return $a['id'];
}

function refreshSession($s) {
   mysqlConnect();
   if ($s && strlen($s) == 64 && sessionActive($s))
      mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL 10 MINUTE WHERE `sessid`="'.$s.'"');
   else return;
}

function closeSession($sess) {
   mysqlConnect();
   mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW() - INTERVAL 1 SECOND WHERE `sessid`="'.$sess.'"');
}


function correctUserName($nick) {
   return strlen($nick)>1 &&
          strlen($nick)<=32 &&
          !preg_match('/[^a-zA-Z0-9а-яА-ЯёЁйЙр_\\- ]/', $nick);
}

function correctMail($mail) {
   return preg_match('/([a-z0-9_\.\-]{1,20})@([a-z0-9\.\-]{1,20})\.([a-z]{2,4})/is', $mail, $res) &&
          $mail == $res[0];
}

function correctAdminPassword($pass) {
   return strlen($pass)<=32 &&
          preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
          $pass == $res[0];
}

function correctUserPassword($pass) {
   return strlen($pass)>3 &&
          strlen($pass)<=32 &&
          preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
          $pass == $res[0];
}

function correctPassword($pass) {
   return preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
          $pass == $res[0];
}

function mySalt($n) {
   $salt = '';
   $a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
   for($i=0; $i<$n; $i++) { $salt.=$a[rand(0,strlen($a)-1)]; }
   return $salt;
}

function registerUser($u, $p, $perm = 0) {
   $salt = mySalt(16);
   $session = generateSessId();
   mysql_query('INSERT INTO `uniusers` (`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`, `permissions`) VALUES ("'.$u.'", "'.$salt.'", "'.myCrypt($p, $salt).'", "'.$session.'", NOW(), NOW() + INTERVAL 10 MINUTE, '.defaultLocation().', '.$perm.')');
   return $session;
}

function validPassword($u, $p) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$u.'"') );
   return $q['hash'] == myCrypt($p, $q['salt']);
}

function userPermissions($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   return $q['permissions'];
}

function fileFromPath($p) {
   if (preg_match('/[^\\\\\\/]+$/', $p, $res)) return $res[0];
}

function setSession($u) {
   mysqlConnect();
   $s = generateSessId();
   mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL 10 MINUTE, `sessid`="'.$s.'" WHERE `user`="'.$u.'"');
   return $s;
}

function redirect($i = DEFAULT_INSTANCE) {
   header('Location: index.php?instance='.$i);
}


/************************* GAME ***************************/
function defaultLocation() {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `default`=1') );
   return $q['id'];
}

function userLocationId($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   return $q['location'];
}

function userAreaId($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.userLocationId($s).'"') );
   return $q['super'];
}

function currentLocationTitle($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc (mysql_query('SELECT * FROM `locations` WHERE `id`="'.userLocationId($s).'"'));
   return $q['title'];
}

function currentAreaTitle($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `areas` WHERE `id`="'.userAreaId($s).'"') );
   return $q['title'];
}

function currentLocationDescription($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.userLocationId($s).'"') );
   return $q['description'];
}

function allowedZones($s, $idsonly = false) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.userLocationId($s).'"') );
   $a = array(); $i = 0;
   foreach (explode('|', $q['goto']) as $v) {
      $la = explode('=', $v);
      $a[$i++] = $idsonly ? $la[1] : array (to => $la[1], name => $la[0]);
   }
   return $a;
}

function changeLocation($s, $lid) {
   mysqlConnect();
   if (in_array( $lid, allowedZones($s, true) ) ) {
      mysql_query('UPDATE `uniusers` SET `location` = '.$lid.' WHERE `sessid`="'.$s.'"');
      return true;
   }
   else return false;
}

function usersOnLocation($s) {
   $q = mysql_query( 'SELECT `user`, `id` FROM `uniusers` WHERE `sessexpire` > NOW() AND `location`='.userLocationId($s) );
   for ($a=array(), $i=0; $q && $r = mysql_fetch_assoc($q); $a[$i++]=array(id => $r['id'], name => $r['user']) );
   return $a;
}
/************************* GAME ***************************/



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

function insertEncoding($e) {
   header('Content-Type: text/html; charset='.$e);
}

function makePage($head, $body, $enc) {
   return
   "<!DOCTYPE html>\n".
   "<html>\n".
   "<head>\n".
   $head.
   '<meta charset="'.$enc.'" />'.
   "\n</head>\n".
   "<body>\n".
   $body.
   "\n</body>\n".
   "</html>";
}


?>
