<?php

require_once('utils.php');
mysqlConnect();

if ($_COOKIE && $_COOKIE['sessid'] && strlen($_COOKIE['sessid'])==64 )
   if (mysql_num_rows(mysql_query('SELECT * FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"')) &&
       mysqlBool('SELECT `sessexpire` > NOW() FROM `uniusers` WHERE `sessid`="'.$_COOKIE['sessid'].'"')) header('location: index.php');

if ($_POST) {
     if ( ( (correctUserName($_POST['user_mail']) && userExists($_POST['user_mail'])) || (correctMail($_POST['user_mail']) && mailExists($_POST['user_mail'])) ) && correctUserPassword($_POST['pass']) && mysql_num_rows($q = mysql_query('SELECT * FROM `uniusers` WHERE `user`="'.$_POST['user_mail'].'" OR `mail`="'.$_POST['user_mail'].'"')) ){
          $q = mysql_fetch_assoc($q);
          if ( $q['hash'] == myCrypt($_POST['pass'], $q['salt']) ) {
             $session = generateSessId();
             setcookie('sessid', $session);
             mysql_query('UPDATE `uniusers` SET `sessexpire` = NOW()+1000, `sessid`="'.$session.'"');
             echo '<meta http-equiv="refresh" content="3;url=index.php">Login success.<br/>';
          }
    }
    else {
       if ( !correctUserName($_POST['user_mail']) || !correctMail($_POST['mail']) || !correctUserPassword($_POST['pass']) ) 
          echo '<span style="background-color: #f00">'.
          implode( ', ', array_filter( array( (correctUserName($_POST['user_mail'])?'':'nick'), (correctMail($_POST['mail'])?'':'email'), (correctAdminPassword($_POST['pass'])?'':'password') ) ) ).
          ' incorrect. Type correct data.</span><br/>';
          
       else if ( !userExists($_POST['user_mail']) && !mailExists($_POST['mail']) )
          echo '<span style="background-color: #f00">User not exists. Try another.</span><br/>';
       
       else echo '<span style="background-color: #f00">Wrong password.</span><br/>';
       
       echo loginForm($_POST['user_mail'], $_POST['pass']);
    }
}
else {
   echo loginForm();
}






function loginForm($ne = '', $p = '') {
   return
   'Login.'.
   '<form method="post" action="login.php" name="reg">'.
   'Nick or E-mail: <input type="text" name="user_mail" maxlength=46 value="'.$ne.'"><br/>'.
   'Password: <input type="password" name="pass" maxlength=32 value="'.$p.'"><br/>'.
   '<input type="submit"value="Send"/><br/>'.
   '</form>';
}



?>