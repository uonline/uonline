<?php

require_once('utils.php');

$HEAD = $BODY = '';

if ($_POST) {
   $u = $_POST['user']; $p = $_POST['pass']; //$e = $_POST['mail'];
   if (correctUserName($u) && !userExists($u) && /*correctMail($e) && !mailExists($e) &&  */ correctUserPassword($p)) {
      $s = registerUser($u, $p);
      setcookie('sessid', $s);
      userRegistered();
   }
   else {
      if ( !correctUserName($u) || /* !correctMail($e) || */ !correctUserPassword($p) )
         incorrectDatas( array( !correctUserName($u), /* !correctMail($e), */ !correctUserPassword($p) ) );
          
      if (userExists($u) /* || mailExists($e) */ )
         alreadyExists( array(userExists($u) /* , mailExists($e) */) );
       
      regForm($u, $p /* , $e */);
   }
}
else {
   regForm();
}

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');




function userRegistered() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=/">';
   $BODY .= 'Пользователь зарегистрирован.<br/>';
}

function alreadyExists($a) {
   global $BODY;
   $BODY .=
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array( 'ник' /* , 'e-mail' */ ), $a ) ).
   ' уже существу'.(count(array_filter($a))>1?'ю':'е').'т. Попробуйте другие.</span><br/>';
}

function incorrectDatas($a) {
   global $BODY;
   $BODY .=
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array('ник', /*'e-mail', */ 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}

function regForm($n = '', $p = '' /* ,$e = '' */) {
   global $BODY;
   $BODY .=
   'Регистрация пользователя.'.
   '<form method="post" action="reg.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><i> От 2 до 32 символов, [a-zA-Z0-9а-яА-Я_- ].</i><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre"> От 4 до 32 символов, [a-zA-Z0-9!@#$%^&*()_+]</i><br/>'.
##   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   '<input type="submit" value="Регистрация" /><br/>'.
   '</form>';
}



?>