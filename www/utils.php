<?php

function mysqlConnect($domain = 'localhost', $user = 'root', $pass = '', $db = 'universe') {   
   @mysql_connect($domain, $user, $pass) or die('Error connecting to database: '.mysql_error());
   mysql_select_db($db);
}

function correctUserName($nick) {
   if (strlen($nick)>2 &&
       strlen($nick)<=16 &&
       !preg_match('/[^a-zA-Z]/', $nick)) return true;
   else return false;
}

function correctEmail($mail) {
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
   ##
}

function mySalt() {
   $salt = '';
   $a = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
   for($i=0; $i<16; $i++){ $salt.=$a[rand(0,51)]; }
   return $salt;
}

function myCrypt($pass, $salt) {
   return crypt($pass, '$6$rounds=10000$'.$salt.'$');
}
?>