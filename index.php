<?php
//error_reporting(E_ALL); ini_set('display_errors', 'on');
$time_start = microtime(true);

require_once 'utils.php';
require_once './Twig/Autoloader.php';

Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array('cache' => TWIG_CACHE));


$redirect = false;

$s = $_COOKIE['sessid']; refreshSession($s);
$se = $_GET['instance']; if($se[strlen($se)-1] == '/') $se = substr($se, 0, strlen($se)-1);

$il = array('register', 'login', 'game', 'about');
$in = in_array($se, $il) ? $se : DEFAULT_INSTANCE;

$options = array(
    'instance' => $in,
    'admin' => userPermissions($s) && sessionActive($s),
    'loggedIn' => sessionActive($s),
    'login' => userBySession($s),
    'mail_count' => 0,
);



/******************* register ***********************/
if ($in == 'register') {
   if ($_POST) {
      $u = $_POST['user']; $p = $_POST['pass'];
      if (correctUserName($u) && !userExists($u) && correctUserPassword($p)) {
         $s = registerUser($u, $p); setcookie('sessid', $s); header('Location: index.php'); die;
      }
      else {
         if ( !correctUserName($u) || !correctUserPassword($p) ) $error = true; elseif (userExists($u)) $error = true; else $error = true;
      }
   }
   $options['title'] = 'Регистрация';
   $options['invalidLogin'] = !correctUserName($u) && $_POST; // логин хуйня
   $options['invalidPass'] = !correctUserPassword($p) && $_POST; // тут хуйня
   $options['loginIsBusy'] = userExists($u) && $_POST; // логин занят
   $options['user'] = $u;
   $options['pass'] = $p;
   $options['error'] = $error;
}
/******************* register ***********************/

/******************* login ***********************/
elseif ($in == 'login') {
   if ($_POST) {
      $u = $_POST['user']; $p = $_POST['pass'];
      if (correctUserName($u) && userExists($u) && correctPassword($p) && validPassword($u, $p)) {
         $s = setSession($u); setcookie('sessid', $s); $redirect = 'about';
      } else {
         if (!correctUserName($u) || !correctPassword($p)) $error = true; elseif (!userExists($u)) $error = true; else $error = true;
      }
   }
   $options['title'] = 'Вход';
   $options['user'] = $u;
   $options['error'] = $error;
}
/******************* login ***********************/

/******************* game ***********************/
elseif ($in == 'game') {
   $redirect = 'login';

   $options['title'] = 'Игра';
   $options['location_name'] = currentLocationTitle($s);
   $options['area_name'] = currentAreaTitle($s);
   $options['pic'] = 'img/sasuke.jpeg';
   $options['description'] = currentLocationDescription($s);
   $options['ways'] = allowedZones($s);
   $options['players_list'] = usersOnLocation($s);
}
/******************* game ***********************/

/******************* moving ***********************/
elseif ($in == 'go') {
   if ($to = $_GET['to']) {
      changeLocation($s, $to);
      $redirect = 'game';
   }
}
/******************* moving ***********************/



if ($redirect) { redirect($redirect); }
else {
   echo $twig->render( $in.'.twig', $options );
   $time_end = microtime(true);
   echo "\n<!-- Done in " . ( ($time_end - $time_start) * 1000) . ' milliseconds -->';
}

?>