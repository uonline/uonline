<?php

require_once('utils.php');

mysqlConnect();

if (!mysql_errno()) die('Bases already exists.');

if ($_SERVER[QUERY_STRING]) {
    if (correctUserName($_GET['user']) && correctEmail($_GET['mail']) && correctAdminPassword($_GET['pass'])) {
       mysql_query('CREATE DATABASE universe');
       mysqlConnect();
       mysql_query('CREATE TABLE `uniusers`(`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` TIMESTAMP, `reg_time` TIMESTAMP, `id` int(10) auto_increment, PRIMARY KEY  (`id`) )');
       $salt = mySalt();
       mysql_query('INSERT INTO `uniusers`(`user`, `mail`, `salt`, `hash`, `reg_time`) VALUES ("'.$_GET['user'].'", "'.$_GET['mail'].'", "'.$salt.'", "'.myCrypt($_GET['pass'], $salt).'",'.time().')') or die('Error database: '.mysql_error());
       echo 'User registered.<br/>';
    }
    else {
       echo '<span style="background-color: #f00">'.
            implode( ', ', array_filter( array( (correctUserName($_GET['user'])?'':'nick'), (correctEmail($_GET['mail'])?'':'email'), (correctAdminPassword($_GET['pass'])?'':'password') ) ) ).
            ' incorrect. Type correct data.</span><br/>';
       echo regForm($_GET['user'], $_GET['pass'], $_GET['mail']);
    }
}
else {
   echo regForm();
}



function regForm($n = 'admin', $p = '', $e = '') {
   return
   'Admin settings'.
   '<form method="get" action="init.php" name="reg">'.
   'Nick: <input type="text" name="user" maxlength=16 value="'.$n.'"><i>From 3 to 16 characters, [!@#$%^&*()_+].</i><br/>'.
   'Password: <input type="password" name="pass" maxlength=32 value="'.$p.'"><i>From 10 to 32 characters, at least one special symbol [!@#$%^&*()_+], digit and letter in both cases.</i><br/>'.
   'E-mail: <input type="text" name="mail" maxlength=46 value="'.$e.'"><br/>'.
   '<input type="submit"value="Send"/><br/>'.
   '</form>';
}

?>