<?php

require_once('utils.php');

$HEAD = $BODY = '';

if (!$_COOKIE['sessid'] || strlen($s = $_COOKIE['sessid'])!=64) header('Location: index.php');
else {
   if (sessionExpired($s)) header('Location: index.php');
   else {
      closeSession($s);
      logoutSuccess(userBySession($s));
   }
}

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');





function logoutSuccess($user) {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=index.php">';
   $BODY .= 'Сессия '.$user.' завершена.';
}


?>