<?php

require_once('utils.php');

$HEAD = $BODY = '';

if (!$_COOKIE['sessid'] || strlen($sess = $_COOKIE['sessid'])!=64) { foe(); }
else {
   $BODY .= (sessionExists($sess)?(sessionExpire($sess).'<br/>'):''); //remove

   if ( !sessionExists($sess) ) foe();
   else
      if( sessionExpired($sess) ) friend();
      else {
         friend( userBySession($sess) );
         refreshSession($sess);
      }
}


insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');



function foe() {
   global $BODY;
   $BODY .= 
   '<i>Я тебя не знать!</i><br/>'.
   '<i><a href="reg.php">Зарегистрироваться</a> или <a href="login.php">войти</a>.</i>';
}

function friend($user='') {
   global $BODY;
   $BODY.=
   $user?
   'Привет, '.$user.'. <i><a href="logout.php">Выход</a></i>.':
   'Сессия истекла. <i><a href="login.php">Вход</a></i>.';
}

?>