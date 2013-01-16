<?php

require_once('utils.php');

$HEAD = $BODY = '';

if (!$_COOKIE['sessid'] || strlen($sess = $_COOKIE['sessid'])!=64) header('location: index.php');
else {
   if (sessionExpired($sess)) header('location: index.php');
   else {
      closeSession($sess);
      logoutSuccess(userBySession($sess));
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