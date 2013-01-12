<?php

require_once('utils.php');

mysqlConnect();

if ($_POST) {
   if (correctUserName($_POST['user']) && !userExists($_POST['user']) && /*correctMail($_POST['mail']) && !mailExists($_POST['mail']) && */ correctAdminPassword($_POST['pass']) && $_POST['ad_pass'] == ADMIN_PASS) {
      $salt = mySalt(16); $session = generateSessId();
      setcookie('sessid', $session);
      mysql_query('INSERT INTO `uniusers` (`user`, /*`mail`,*/ `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`) VALUES ("'.$_POST['user'].'", /*"'.$_POST['mail'].'",*/ "'.$salt.'", "'.myCrypt($_POST['pass'], $salt).'", "'.$session.'", NOW(), NOW()+1000)');
      echo '<meta http-equiv="refresh" content="3;url=index.php">Зарегистрирован.<br/>';
   }
   else {
      if ($_POST['ad_pass'] != ADMIN_PASS) echo wrongPass();
         else
             if (!correctUserName($_POST['user']) || /* correctMail($_POST['mail']) || */ !correctAdminPassword($_POST['pass'])) echo incorrectDatas( array( !correctUserName($_POST['user']), /* correctMail($_POST['mail']), */ !correctAdminPassword($_POST['pass']) ) );
             else echo alreadyExists( array (userExists($_POST['user']) /*, mailExists($_POST['mail']) */ ) );
      echo regForm($_POST['user'], $_POST['pass'] /* , $_POST['mail'] */ );
   }
}
else {
   echo regForm();
}

function alreadyExists($a) {
   return
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array( 'ник' /* , 'e-mail' */ ), $a ) ).
   ' уже существу'.(count(array_filter($a))>1?'ю':'е').'т. Попробуйте другие.</span><br/>';
}

function wrongPass() {
   return '<!-- meta http-equiv="refresh" content="3;url=login.php" --><span style="background-color: #f00">Неверный административный пароль.</span><br/>';
}

function incorrectDatas($a) {
   return '<span style="background-color: #f00">'.
          implode( ', ', array_filter_( array('ник', /* 'e-mail', */ 'пароль'), $a ) ).
          ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}

function regForm($n = 'admin', $p = '', $e = '') {
   return
   'Регистрация администратора.'.
   '<form method="post" action="add-admin.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><i>От 2 до 32 символов, [a-zA-Z0-9а-яА-Я_- ].</i><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre">До 32 символов, [a-zA-Z0-9!@#$%^&*()_+].</i><br/>'.
##   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   'Администраторский пароль: <input name="ad_pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'"/><br/>'.
   '<input type="submit"value="Send"/><br/>'.
   '</form>';
}

?>