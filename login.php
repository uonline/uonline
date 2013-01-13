<?php

require_once('utils.php');

mysqlConnect();

if ($_COOKIE && $_COOKIE['sessid'] && strlen($_COOKIE['sessid'])==64 && sessionExists($_COOKIE['sessid']) && sessionActive($_COOKIE['sessid']) ) header('location: index.php');

if ($_POST) {
   if ( ( correctUserName($_POST['user']) && userExists($_POST['user']) ) && correctPassword($_POST['pass']) && mysql_num_rows($q = mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$_POST['user'].'"')) ) {
      $r = mysql_fetch_assoc($q);
      if ( $r['hash'] == myCrypt($_POST['pass'], $r['salt']) ) {
         $session = generateSessId();
         setcookie('sessid', $session);
         mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW()+1000, `sessid`="'.$session.'" WHERE `user`="'.$_POST['user'].'"');
         
         $q = mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$_POST['user'].'"');
         $r = mysql_fetch_assoc($q);
         echo $r['sessexpire'].'<br/>';
         
         echo '<meta http-equiv="refresh" content="3;url=index.php">Успешный вход.<br/>';
      }
      else {
         echo wrongPass();
      }
   }
   else {
       if ( !correctUserName($_POST['user']) || !correctPassword($_POST['pass']) ) 
          echo incorrectData( array( !correctUserName($_POST['user']), !correctPassword($_POST['pass']) ) );
          
       else if ( !userExists($_POST['user']) && !mailExists($_POST['mail']) ) echo userNotExists();
       
       
       echo loginForm($_POST['user'], $_POST['pass']);
    }
}
else {
   echo loginForm();
}

function loginForm($n = '', $p = '') {
   return
   'Вход.<br/>'.
   '<form method="post" action="login.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><br/>'.
   '<input type="submit"value="Вход"/><br/>'.
   '</form>';
}

function wrongPass() {
   return '<meta http-equiv="refresh" content="3;url=login.php"><span style="background-color: #f00">Неверный пароль.</span><br/>';
}

function userNotExists() {
   return '<span style="background-color: #f00">Пользователя не существует. Попробуйте ввести другой ник.</span><br/>';
}

function incorrectData($a) {
   return
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array('ник', 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}


?>