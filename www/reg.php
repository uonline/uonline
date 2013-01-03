<?php

require_once('utils.php');



if ($_POST) {
    if (correctUserName($_POST['user']) && !userExists($_POST['user']) && correctMail($_POST['mail']) && !mailExists($_POST['mail']) && correctUserPassword($_POST['pass'])) {
       $salt = mySalt(16); $session = generateSessId();
       setcookie('sessid', $session);
       mysql_query('INSERT INTO `uniusers` (`user`, `mail`, `salt`, `hash`, `sessid`, `reg_time`, `sessexpire`) VALUES ("'.$_POST['user'].'", "'.$_POST['mail'].'", "'.$salt.'", "'.myCrypt($_POST['pass'], $salt).'", "'.$session.'", NOW(), NOW()+600)') or die(__LINE__.' Error database: '.mysql_error());
       echo '<meta http-equiv="refresh" content="3;url=index.php">User registered.<br/>';
    }
    else {
       if ( !correctUserName($_POST['user']) || !correctMail($_POST['mail']) || !correctUserPassword($_POST['pass']) ) 
          echo '<span style="background-color: #f00">'.
          implode( ', ', array_filter( array( (correctUserName($_POST['user'])?'':'nick'), (correctMail($_POST['mail'])?'':'email'), (correctAdminPassword($_POST['pass'])?'':'password') ) ) ).
          ' incorrect. Type correct data.</span><br/>';
          
       if (userExists($_POST['user']) || mailExists($_POST['mail']) )
          echo '<span style="background-color: #f00">'.
          implode( ', ', array_filter( array( userExists($_POST['user'])?'nick':'', mailExists($_POST['mail'])?'e-mail':'' ) ) ).
          ' already exists. Try another.</span><br/>';
       
       echo regForm($_POST['user'], $_POST['pass'], $_POST['mail']);
    }
}
else {
   echo regForm();
}






function regForm($n = '', $p = '', $e = '') {
   return
   'New user registration.'.
   '<form method="post" action="reg.php" name="reg">'.
   'Nick: <input type="text" name="user" maxlength=16 value="'.$n.'"><i>From 3 to 16 characters, [a-zA-Z].</i><br/>'.
   'Password: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i style="white-space: pre">From 10 to 32 characters, [a-zA-Z!@#$%^&*()_+].</i><br/>'.
   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   '<input type="submit"value="Send"/><br/>'.
   '</form>';
}



?>