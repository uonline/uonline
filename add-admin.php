<?php

require_once('utils.php');

$HEAD = $BODY = '';

if ($_POST) {
   $u = $_POST['user']; $p = $_POST['pass']; //$e = $_POST['mail'];
   if (correctUserName($u) && !userExists($u) && /*correctMail($e) && !mailExists($e) && */ correctAdminPassword($p) && $_POST['ad_pass'] == ADMIN_PASS) {
      $s = registerUser($u, $p);
      setcookie('sessid', $s);
      registerSuccess();
   }
   else {
      if ($_POST['ad_pass'] != ADMIN_PASS) wrongPass();
      else
         if (!correctUserName($u) || /* correctMail($_POST['mail']) || */ !correctAdminPassword($p)) 
            incorrectDatas( array( !correctUserName($u), /* correctMail($_POST['mail']), */ !correctAdminPassword($p) ) );
         else alreadyExists( array (userExists($u) /*, mailExists($_POST['mail']) */ ) );
      regForm($u, $p /* , $e */ );
   }
}
else {
   regForm();
}

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');








function registerSuccess() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=index.php">';
   $BODY .= 'Зарегистрирован.<br/>';
}

function alreadyExists($a) {
   global $BODY;
   $BODY .=
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array( 'ник' /* , 'e-mail' */ ), $a ) ).
   ' уже существу'.(count(array_filter($a))>1?'ю':'е').'т. Попробуйте другие.</span><br/>';
}

function wrongPass() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=login.php">';
   $BODY .= '<span style="background-color: #f00">Неверный административный пароль.</span><br/>';
}

function incorrectDatas($a) {
   global $BODY;
   $BODY .=
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array('ник', /* 'e-mail', */ 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}

function regForm($n = 'admin', $p = '' /*, $e = '' */) {
   global $BODY;
   $BODY .=
   'Регистрация администратора.'.
   '<form method="post" action="add-admin.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><i>От 2 до 32 символов, [a-zA-Z0-9а-яА-Я_- ].</i><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre">До 32 символов, [a-zA-Z0-9!@#$%^&*()_+].</i><br/>'.
##   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   'Администраторский пароль: <input name="ad_pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'" /><br/>'.
   '<input type="submit" value="Send" /><br/>'.
   '</form>';
}

?>