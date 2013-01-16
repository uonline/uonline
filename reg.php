<?php

require_once('utils.php');



if ($_POST) {
    if (correctUserName($_POST['user']) && !userExists($_POST['user']) && /*correctMail($_POST['mail']) && !mailExists($_POST['mail']) &&  */ correctUserPassword($_POST['pass'])) {
       $salt = mySalt(16); $session = generateSessId();
       setcookie('sessid', $session);
       mysql_query('INSERT INTO `uniusers` (`user`, /*`mail`,*/ `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`) VALUES ("'.$_POST['user'].'", /*"'.$_POST['mail'].'",*/ "'.$salt.'", "'.myCrypt($_POST['pass'], $salt).'", "'.$session.'", NOW(), NOW()+1000)');
       echo userRegistered();
    }
    else {
       if ( !correctUserName($_POST['user']) || /* !correctMail($_POST['mail']) || */ !correctUserPassword($_POST['pass']) )
          echo incorrectDatas( array( !correctUserName($_POST['user']), /* !correctMail($_POST['mail']), */ !correctUserPassword($_POST['pass']) ) );
          
       if (userExists($_POST['user']) /* || mailExists($_POST['mail']) */ )
          echo alreadyExists( array(userExists($_POST['user']) /* , mailExists($_POST['mail']) */) );
       
       echo regForm($_POST['user'], $_POST['pass'] /* , $_POST['mail'] */);
    }
}
else {
   echo regForm();
}





function userRegistered() {
    return '<meta http-equiv="refresh" content="3;url=index.php">Пользователь зарегистрирован.<br/>';
}

function alreadyExists($a) {
   return
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array( 'ник' /* , 'e-mail' */ ), $a ) ).
   ' уже существу'.(count(array_filter($a))>1?'ю':'е').'т. Попробуйте другие.</span><br/>';
}

function incorrectDatas($a) {
   return
   '<span style="background-color: #f00">'.
   implode( ', ', array_filter_( array('ник', /*'e-mail', */ 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.</span><br/>';
}

function regForm($n = '', $p = '' /* ,$e = '' */) {
   return
   'Регистрация пользователя.'.
   '<form method="post" action="reg.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><i> От 2 до 32 символов, [a-zA-Z0-9а-яА-Я_- ].</i><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre"> От 4 до 32 символов, [a-zA-Z0-9!@#$%^&*()_+]</i><br/>'.
##   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   '<input type="submit" value="Регистрация"/><br/>'.
   '</form>';
}



?>