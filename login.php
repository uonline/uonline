<?php

require_once('utils.php');

$HEAD = $BODY = '';

mysqlConnect();

if ($_COOKIE && $s = $_COOKIE['sessid'] && strlen($s)==64 && sessionExists($s) && sessionActive($s) ) header('location: /');

if ($_POST) {
   $u = $_POST['user']; $p = $_POST['pass']; //$e = $_POST['mail'];
   if ( correctUserName($u) && userExists($u) && correctPassword($p) && validPassword($u, $p) ) {
      $s = setSession($u);
      setcookie('sessid', $s);

      $BODY .= sessionExpire($s).'<br/>'; //remove
      
      successLogIn();

   }
   else {
       if ( !correctUserName($u) || !correctPassword($p) ) 
          incorrectData( array( !correctUserName($u), !correctPassword($p) ) );
          
       else if ( !userExists($u) /*&& !mailExists($e) */ ) userNotExists();

       else wrongPass();

       loginForm($u, $p);
    }
}
else {
   loginForm();
}



insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');







function loginForm($n = '', $p = '') {
   global $BODY;
   $BODY.=
   'Вход.<br/>'.
   '<form method="post" action="login.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><br/>'.
   '<input type="submit" value="Вход" /><br/>'.
   '</form>';
}

function wrongPass() {
   global $BODY, $HEAD;
   $HEAD.='<meta http-equiv="refresh" content="3;url=login.php">';
   $BODY.='<span style="background-color: #f00">Неверный пароль.</span><br/>';
}

function userNotExists() {
   global $BODY, $HEAD;
   $HEAD.='<meta http-equiv="refresh" content="3;url=login.php">';
   $BODY.='<span style="background-color: #f00">Пользователя не существует. Попробуйте ввести другой ник.</span><br/>';
}

function incorrectData($a) {
   global $BODY, $HEAD;
   $HEAD.='<meta http-equiv="refresh" content="3;url=login.php">';
   $BODY.=
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array('ник', 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}

function successLogIn() {
   global $BODY, $HEAD;
   $HEAD.='<meta http-equiv="refresh" content="3;url=/">';
   $BODY.='Успешный вход.<br/>';
}


?>