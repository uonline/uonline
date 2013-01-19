<?php

$time_start = microtime(true);

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
   //'cache' => './templates_cache', // UNCOMMENT LATER
   'cache' => false,
));









require_once('utils.php'); $HEAD = $BODY = '';

if ($_POST) {
   $u = $_POST['user']; $p = $_POST['pass'];
   if (correctUserName($u) && !userExists($u) && correctUserPassword($p)) {
      $s = registerUser($u, $p);
      setcookie('sessid', $s);
      userRegistered();
      header('localion: index.php')
   }
   else {
      if ( !correctUserName($u) || !correctUserPassword($p) )
         incorrectDatas( array( !correctUserName($u), !correctUserPassword($p) ) );
          
      if (userExists($u))
         alreadyExists( array(userExists($u) /* , mailExists($e) */) );
       
      regForm($u, $p /* , $e */);
   }
}
else {
   regForm();
}



function regForm() {
   global $BODY, $HEAD, $twig, $u, $p;
   echo $twig->render('register.twig', array(
      'error' => $BODY ? $BODY : false,
      'invalidLogin' => !correctUserName($u) && $_POST, // логин хуйня
      'invalidPass' => !correctUserPassword($p) && $_POST, // тут хуйня
      'loginIsBusy' => userExists($u) && $_POST, // логин занят
      'user' => $u,
      'pass' => $p,
));

   die;

}

function userRegistered() {
   global $BODY, $HEAD, $twig;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=index.php">';
   $BODY .= 'Пользователь зарегистрирован.';
}

function alreadyExists($a) {
   global $BODY, $twig;
   $BODY .=
   implode( ', ', array_filter_( array( 'ник' /* , 'e-mail' */ ), $a ) ).
   ' уже существу'.(count(array_filter($a))>1?'ю':'е').'т. Попробуйте другие.';
}

function incorrectDatas($a) {
   global $BODY, $twig;
   $BODY .=
   implode( ', ', array_filter_( array('ник', /*'e-mail', */ 'пароль'), $a ) ).
   ' неправильны'.(count(array_filter($a))>1?'е':'й').'. Введите корректные данные.';
}

$time_end = microtime(true);
echo "\n<!-- Done in ".( ($time_end - $time_start) *1000).' milliseconds -->';


?>