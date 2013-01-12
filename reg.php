<?php

require_once('utils.php');



if ($_POST) {
    if (correctUserName($_POST['user']) && !userExists($_POST['user']) && correctMail($_POST['mail']) && !mailExists($_POST['mail']) && correctUserPassword($_POST['pass'])) {
       $salt = mySalt(16); $session = generateSessId();
       setcookie('sessid', $session);
       mysql_query('INSERT INTO `uniusers` (`user`, `mail`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`) VALUES ("'.$_POST['user'].'", "'.$_POST['mail'].'", "'.$salt.'", "'.myCrypt($_POST['pass'], $salt).'", "'.$session.'", NOW(), NOW()+600)') or die(__LINE__.' Error database: '.mysql_error());
       echo '<meta http-equiv="refresh" content="3;url=index.php">Пользователь зарегистрирован.<br/>';
    }
    else {
       if ( !correctUserName($_POST['user']) || !correctMail($_POST['mail']) || !correctUserPassword($_POST['pass']) ) 
          echo '<span style="background-color: #f00">'.
          implode( ', ', array_filter( array( (correctUserName($_POST['user'])?'':'ник'), (correctMail($_POST['mail'])?'':'e-mail'), (correctAdminPassword($_POST['pass'])?'':'пароль') ) ) ).
          ' неверны. Введите корректные данные.</span><br/>';
          
       if (userExists($_POST['user']) || mailExists($_POST['mail']) )
          echo '<span style="background-color: #f00">'.
          implode( ', ', array_filter( array( userExists($_POST['user'])?'ник':'', mailExists($_POST['mail'])?'e-mail':'' ) ) ).
          ' уже существует. Попробуйте другие.</span><br/>';
       
       echo regForm($_POST['user'], $_POST['pass'], $_POST['mail']);
    }
}
else {
   echo regForm();
}






function regForm($n = '', $p = '', $e = '') {
   return
   'Регистрация пользователя.'.
   '<form method="post" action="reg.php" name="reg">'.
   'Ник: <input type="text" name="user" maxlength=16 value="'.$n.'"><i> От 3 до 16 символов, [a-zA-Z].</i><br/>'.
   'Пароль: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre"> От 10 до 32 символов, [a-zA-Z0-9!@#$%^&*()_+]</i><br/>'.
   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   '<input type="submit"value="Регистрация"/><br/>'.
   '</form>';
}



?>