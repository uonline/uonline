<?php

require_once('utils.php');

if (!$_COOKIE['sessid'] || strlen($_COOKIE['sessid'])!=64) header('location: index.php');
else {
   mysqlConnect();
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"') );
   if (!$a || mysqlBool('SELECT `sessexpire` < NOW() FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"')) header('location: index.php');
   else { echo out($a['user']); mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW()-1'); }
}

function out($user) {
   return '<meta http-equiv="refresh" content="3;url=index.php">Сессия '.$user.' завершена.';
}


?>