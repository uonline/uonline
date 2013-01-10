<?php

require_once('utils.php');

if ($_POST) {
   if ($_POST['ad_pass'] == ADMIN_PASS) {
      mysqlConnect();
      mysql_query('DROP DATABASE '.MYSQL_BASE);
      echo mysql_error() ? '<meta http-equiv="refresh" content="3;url=drop.php"><span style="color: red">Ошибка.</span>' : '<meta http-equiv="refresh" content="3;url=index.php">Успех.';
   }
   else {
      echo '<meta http-equiv="refresh" content="3;url=drop.php"><span style="color: red">Пароль неверный.</span><br/>';
      echo fofForm();
   }
}
else {
   echo fofForm();
}

function fofForm() {
   return '<form method="post" action="drop.php">'.
          'Удаление базы данных.<br/>'.
          'Администраторский пароль: <input name="ad_pass" type="password"/><br/>'.
          '<input type="submit" value="Удалить"/><br/>';
}

?>