<?php

$time_start = microtime(true);

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
   //'cache' => './templates_cache', // UNCOMMENT LATER
   'cache' => false,
));


require_once('utils.php'); $s = $_COOKIE['sessid']; $ca = array();
if ($s && strlen($s) == 64 && sessionActive($s)) refreshSession($s);

if ($se = $_GET['section']) {
   
   /******************* register ***********************/
   if ($se == 'register') {
      if ($_POST) {
         $u = $_POST['user']; $p = $_POST['pass'];
         if (correctUserName($u) && !userExists($u) && correctUserPassword($p)) {
            $s = registerUser($u, $p); setcookie('sessid', $s); header('Location: index.php'); die;
         }
         else {
            if ( !correctUserName($u) || !correctUserPassword($p) ) $error = true;
            elseif (userExists($u)) $error = true;
            else $error = true;
         }
      }
      $page = 'register.twig';
      $ca = array(
         'section' => 'register',
         'title' => 'Регистрация',

         'invalidLogin' => !correctUserName($u) && $_POST, // логин хуйня
         'invalidPass' => !correctUserPassword($p) && $_POST, // тут хуйня
         'loginIsBusy' => userExists($u) && $_POST, // логин занят

         'user' => $u,
         'pass' => $p,
         'error' => $error,
      );
   }
   /******************* register ***********************/
   
   /******************* login ***********************/
   elseif ($se == 'login') {
      if ($_POST) {
         $u = $_POST['user']; $p = $_POST['pass'];
         if (correctUserName($u) && userExists($u) && correctPassword($p) && validPassword($u, $p)) {
            $s = setSession($u); setcookie('sessid', $s); header('Location: index.php'); die;
         } else {
            if (!correctUserName($u) || !correctPassword($p)) $error = true;
            else if (!userExists($u)) $error = true;
            else $error = true;
         }
      }

      $page = 'login.twig';
      $ca = array(
          'section' => 'login',
          'title' => 'Вход',
          
          'user' => $u,
          
          'error' => $error,
      );
   }
   /******************* login ***********************/
   
   /******************* game ***********************/
   elseif ($se == 'game') {
      if ($s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
      else { header('Location: login.php'); die; }

      if ($_GET && $to = $_GET['to']) {
         changeLocation($s, $to);
      }
      $page = 'game.twig';
      $ca = array(
         'section' => 'game',
         'title' => 'Игра',

         'location_name' => currentLocationTitle($s),
         'area_name' => currentAreaTitle($s),
         'pic' => 'img/sasuke.jpeg',
         'description' => currentZoneDescription($s),
         'ways' => allowedZones($s),
         'players_list' => array( array( id => idBySession($s), name => userBySession($s) ) ),
      );
   }
   /******************* game ***********************/
}

echo $twig->render($page ? $page : 'index.twig', $ca + array(
    'admin' => userPermissions($s) && sessionActive($s),
    'loggedIn' => sessionActive($s),
    'login' => userBySession($s),
    'mail_count' => 0,
));

$time_end = microtime(true);
echo "\n<!-- Done in " . ( ($time_end - $time_start) * 1000) . ' milliseconds -->';
?>