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
$in = $_GET['instance']; if($in[strlen($in)-1] == '/') $in = substr($in, 0, strlen($in)-1);

$options = array(
    'instance' => $in,
    'admin' => userPermissions($s) && sessionActive($s),
    'loggedIn' => sessionActive($s),
    'login' => userBySession($s),
    'mail_count' => 0,
);

$il = array('register', 'logout', 'login', 'game', 'about', 'go', 'profile');
if (!$in) $redirect = DEFAULT_INSTANCE;
if (!in_array($in, $il)) {
   $in = '404';
   header( $_SERVER[SERVER_PROTOCOL].' 404 Not Found' );
}



/******************* register ***********************/
if ($in == 'register') {
   if ($_POST) {
      $u = $_POST['user']; $p = $_POST['pass'];
      if (correctUserName($u) && !userExists($u) && correctUserPassword($p)) {
         $s = registerUser($u, $p); setcookie('sessid', $s); $redirect = DEFAULT_INSTANCE;
      }
      else {
         if ( !correctUserName($u) || !correctUserPassword($p) ) $error = true; elseif (userExists($u)) $error = true; else $error = true;

         $options['invalidLogin'] = !correctUserName($u) && $_POST; // логин хуйня
         $options['invalidPass'] = !correctUserPassword($p) && $_POST; // тут хуйня
         $options['loginIsBusy'] = userExists($u) && $_POST; // логин занят
         $options['user'] = $u;
         $options['pass'] = $p;
         $options['error'] = $error;
      }
   }
}
/******************* register ***********************/

/******************* login ***********************/
elseif ($in == 'login') {
   if ($_POST) {
      $u = $_POST['user']; $p = $_POST['pass'];
      if (correctUserName($u) && userExists($u) && correctPassword($p) && validPassword($u, $p)) {
         $s = setSession($u); setcookie('sessid', $s); $redirect = DEFAULT_INSTANCE;
      } else {
         if (!correctUserName($u) || !correctPassword($p)) $error = true; elseif (!userExists($u)) $error = true; else $error = true;
      }
   }
   $options['user'] = $u;
   $options['error'] = $error;
}
/******************* login ***********************/

/******************* profile ***********************/
elseif ($in == 'profile') {
   if (true) {
      $chrs = userCharacters($s);
      foreach ($chrs as $k => $v) {
         $options[$k] = $v;
      }
   }
}
/******************* profile ***********************/

/******************* logout ***********************/
elseif ($in == 'logout') {
   if (sessionActive($s)) {
      closeSession($s);
      $redirect = 'about';
   }
   else $redirect = 'about';
}
/******************* logout ***********************/

/******************* game ***********************/
elseif ($in == 'game') {
   if (sessionExpired($s)) $redirect = 'login';
   else {
      $options['location_name'] = currentLocationTitle($s);
      $options['area_name'] = currentAreaTitle($s);
      $options['pic'] = '/img/Sasuke.jpeg';
      $options['description'] = currentLocationDescription($s);
      $options['ways'] = allowedZones($s);
      $options['players_list'] = usersOnLocation($s);
   }
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
