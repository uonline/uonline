<?php

require_once('utils.php');

##$ar = array('hell', 'пре в_е-д', 'Збса', 'ррр', 'Рид');

##foreach ($ar as $a=>$b) {
##   preg_match('/[^a-zA-Z0-9а-яА-ЯёЁйЙр_\\- ]/', $b, $res);
##   echo $b.' => '.(correctUserName($b)?'1':'0').' => '.$res[0].'<br/>';
##}

if (!$_COOKIE['sessid'] || strlen($_COOKIE['sessid'])!=64) echo foe();
else {
   mysqlConnect();
   $a = mysql_fetch_assoc ( mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"') );
   echo $a['sessexpire'].'<br/>';
   if (!$a) echo foe();
   else if( mysqlBool('SELECT `sessexpire` < NOW() FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"') ) echo friend();
        else { echo friend($a['user']); mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW()+1000 /*10 minutes*/ WHERE `sessid`="'.$_COOKIE['sessid'].'"'); }
}


function foe() {
   return '<i>Я тебя не знать!</i><br/>'.
          '<i><a href="reg.php">Зарегистрироваться<a/> или <a href="login.php">войти</a>.<i/>';
}

function friend($user='') {
   return $user?
          'Привет, '.$user.'. <i><a href="logout.php">Выход</a></i>.':
          'Сессия истекла. <i><a href="login.php">Вход</a></i>.';
}


?>