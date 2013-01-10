<?php

require_once('utils.php');

if ($_POST) {
   if ($_POST['pass'] == ADMIN_PASS) {
      mysqlInit();
      echo mysql_error() ? '<meta http-equiv="refresh" content="3;url=init.php"><span style="color: red">Ошибка.</span>' : '<meta http-equiv="refresh" content="3;url=index.php">Успех.';
   }
   else {
      echo '<meta http-equiv="refresh" content="3;url=init.php"><span style="color: red">Пароль неверный.</span><br/>';
      echo fofForm();
   }
}
else {
   echo fofForm();
}

function fofForm() {
   return '<form method="post" action="init.php">'.
          'Создание базы данных.<br/>'.
          'Администраторский пароль: <input name="pass" type="password"/><br/>'.
          '<input type="submit" value="Создать"/><br/>';
}

?>