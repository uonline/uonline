<?php

require_once('utils.php');

$HEAD = $BODY = '';

if ($_POST) {
   if ($_POST['pass'] == ADMIN_PASS) {
      mysqlInit();
      mysql_error() ? initError(): initSuccess();
   }
   else {
      wrongPass();
      fofForm();
   }
}
else fofForm();

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');







function wrongPass() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
   $BODY .= '<span style="color: red">Пароль неверный.</span><br/>';
}

function initError() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
   $BODY .= '<span style="color: red">Ошибка.</span>';
}

function initSuccess() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=index.php">';
   $BODY .= 'Успех.';
}

function fofForm() {
   global $BODY;
   $BODY .=
   '<form method="post" action="init.php">'.
   'Создание базы данных.<br/>'.
   'Административный пароль: <input name="pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'"/><br/>'.
   '<input type="submit" value="Создать"/><br/>';
}

?>