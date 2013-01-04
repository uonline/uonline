<?php

require_once('utils.php');

if (!$_COOKIE['sessid'] || strlen($_COOKIE['sessid'])!=64) echo foe();
else {
   mysqlConnect();
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"') );
   if (!$a) echo foe();
   else if( (mysqlBool('SELECT `sessexpire` < NOW() FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"')) ) echo friend();
        else { echo friend($a['user']); mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW()+1000 /*10 minutes*/'); }
}


function foe() {
   return '<i>I don\'t know you!</i><br/>'.
          '<i><a href="reg.php">Sign up<a/> or <a href="login.php">sign in</a>!<i/>';
}

function friend($user='') {
   return $user?
          'Hello, '.$user:
          'Session expired. <i><a href="login.php">Sign in</a></i>.';
}


?>