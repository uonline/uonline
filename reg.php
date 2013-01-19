<?php
require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
	// UNCOMMENT LATER
   // 'cache' => './templates_cache',
   'cache' => false,
));









require_once('utils.php'); $HEAD = $BODY = '';

print_r($_POST);

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



function regForm() {
   global $BODY, $HEAD, $twig;
   echo $twig->render('register.twig', array(
      'error' => $BODY ? $BODY : false
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



?>