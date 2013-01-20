<?php

require_once('config.php');


function mysqlInit($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {   
   defined("MYSQL_CONN") || define ("MYSQL_CONN", mysql_connect($host, $user, $pass) );
   mysql_query('CREATE DATABASE IF NOT EXISTS `'.$base.'`');
   mysql_select_db($base);
   mysql_query('CREATE TABLE IF NOT EXISTS `uniusers` (`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` DATETIME, `reg_time` DATETIME, `id` INT AUTO_INCREMENT, `location` INT, PRIMARY KEY  (`id`) )');
   mysql_query('CREATE TABLE IF NOT EXISTS `locations` (`title` TINYTEXT, `name` TINYTEXT, `type` TINYTEXT, `goto` TINYTEXT, `parent` TINYTEXT, `description` TINYTEXT, `id` INT, `default` TINYINT(1) ) ');
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

function refreshSession($sess) {
   mysqlConnect();
   mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL 10 MINUTE WHERE `sessid`="'.$sess.'"');
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

function registerUser($u, $p, $e = NULL) {
   $salt = mySalt(16);
   $session = generateSessId();
   mysql_query('INSERT INTO `uniusers` (`user`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`, `location`) VALUES ("'.$u.'", "'.$salt.'", "'.myCrypt($p, $salt).'", "'.$session.'", NOW(), NOW() + INTERVAL 10 MINUTE, "'.defaultLocation().'")');
   return $session;
}

function validPassword($u, $p) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$u.'"') );
   return $q['hash'] == myCrypt($p, $q['salt']);
}

function setSession($u) {
   mysqlConnect();
   $s = generateSessId();
   mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW() + INTERVAL 10 MINUTE, `sessid`="'.$s.'" WHERE `user`="'.$u.'"');
   return $s;
}


/************************* GAME ***************************/
function defaultLocation() {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `default`=1') );
   return $q['id'];
}

function userLocation($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   return $q['location'];
}

function currentLocationTitle($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.$q['location'].'"') );
   return $q['parent']?$q['title']:false;
}

function currentAreaTitle($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.$q['location'].'"') );
   if (!$q['parent']) return $q['title'];
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `name`="'.$q['parent'].'"') );
   return $q['title'];
}

function currentZoneDescription($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.$q['location'].'"') );
   return $q['description'];
}

function allowedZones($s) {
   mysqlConnect();
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$s.'"') );
   $q = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.$q['location'].'"') );
   $a = array(); $i = 0;
   foreach (explode('|', $q['goto']) as $v) {
      $q0 = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `name`="'.$v.'"') );
      $a[$i++] = array (to => $q0['id'], name => $q0['title']);
   }
   return $a;
}

function changeLocation($s, $lid) {
   mysqlConnect();
   $q0 = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.userLocation($s).'"') );
   $q1 = mysql_fetch_assoc ( mysql_query('SELECT * FROM `locations` WHERE `id`="'.$lid.'"') );
   $con = ($q0['parent']==$q1['parent']) || ($q0['name']==$q1['parent']) || ($q0['parent']==$q1['name']);
   if (in_array( $q1['name'], explode('|', $q0['goto'])) &&  $con) {
      mysql_query('UPDATE `uniusers` SET `location` = '.$lid.' WHERE `sessid`="'.$s.'"');
      return 0;
   }
   else return 5;
}
/**********************************************************/



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