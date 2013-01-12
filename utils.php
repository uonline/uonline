<?php

require_once('config.php');


function mysqlInit($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {   
   defined("MYSQL_CONN") || define ("MYSQL_CONN", mysql_connect($host, $user, $pass) );
   mysql_query('CREATE DATABASE IF NOT EXISTS `'.$base.'`');
   mysql_select_db($base);
   mysql_query('CREATE TABLE IF NOT EXISTS `uniusers` (`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` DATETIME, `reg_time` DATETIME, `id` INT AUTO_INCREMENT, PRIMARY KEY  (`id`) )');
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

function generateSessId() {
   mysqlConnect();
   do $sessid = mySalt(64);
   while ( mysql_fetch_array ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sessid.'"') ) );
   return $sessid;
}

function correctUserName($nick) {
   return strlen($nick)>2 &&
          strlen($nick)<=16 &&
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
   return strlen($pass)>9 &&
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


?>