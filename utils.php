<?php

require_once('config.php');


function mysqlInit($domain = mysql_host, $user = mysql_user, $pass = mysql_pass, $base = mysql_base) {   
   mysql_connect($domain, $user, $pass) or die('Error connecting to database: '.mysql_error());
   mysql_query('CREATE DATABASE IF NOT EXISTS `'.$base.'`') or die(__LINE__.' Error database: '.mysql_error());
   mysql_select_db($base);
   mysql_query('CREATE TABLE IF NOT EXISTS `uniusers` (`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` DATETIME, `reg_time` DATETIME, `id` INT AUTO_INCREMENT, PRIMARY KEY  (`id`) )') or die(' Error database: '.mysql_error());
}

function mysqlConnect($domain = mysql_host, $user = mysql_user, $pass = mysql_pass, $base = mysql_base) {   
   mysql_connect($domain, $user, $pass) or die('Error connecting to database: '.mysql_error());
   mysql_select_db($base);
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

function generateSessId() {
   mysqlConnect();
   do $sessid = mySalt(64);
   while ( mysql_fetch_array ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$sessid.'"') ) );
   return $sessid;
}

function correctUserName($nick) {
   if (strlen($nick)>2 &&
       strlen($nick)<=16 &&
       !preg_match('/[^a-zA-Z]/', $nick)) return true;
   else return false;
}

function correctMail($mail) {
   if (preg_match('/([a-z0-9_\.\-]{1,20})@([a-z0-9\.\-]{1,20})\.([a-z]{2,4})/is', $mail, $res) && $mail == $res[0] ) return true;
   else return false;
}

function correctAdminPassword($pass) {
   if (strlen($pass)>9 &&
       strlen($pass)<=32 &&
       preg_match('/[\!\@\#\$\%\^\&\*\(\)\_\+]/', $pass) &&
       preg_match('/[A-Z]/', $pass) &&
       preg_match('/[a-z]/', $pass) &&
       preg_match('/[0-9]/', $pass) &&
       preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
       $pass == $res[0]) return true;
   else return false;
}

function correctUserPassword($pass) {
   if (strlen($pass)>9 &&
       strlen($pass)<=32 &&
       preg_match( '/[\!\@\#\$\%\^\&\*\(\)\_\+A-Za-z0-9]+/', $pass, $res) &&
       $pass == $res[0]) return true;
   else return false;
}

function mySalt($n) {
   $salt = '';
   $a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
   for($i=0; $i<$n; $i++) { $salt.=$a[rand(0,strlen($a)-1)]; }
   return $salt;
}

function myCrypt($pass, $salt) {
   return crypt($pass, '$6$rounds=10000$'.$salt.'$');
}
?>