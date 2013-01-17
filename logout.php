<?php

require_once('utils.php');

$HEAD = $BODY = '';

if (!$_COOKIE['sessid'] || strlen($s = $_COOKIE['sessid'])!=64) header('location: /');
else {
   if (sessionExpired($s)) header('location: /');
   else {
      closeSession($s);
      logoutSuccess(userBySession($s));
   }
}

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');





function logoutSuccess($user) {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=/">';
   $BODY .= 'Сессия '.$user.' завершена.';
}


?>