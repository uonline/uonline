<?php
//error_reporting(E_ALL); ini_set('display_errors', 'on');
$time_start = microtime(true);

require_once 'utils.php';
require_once './Twig/Autoloader.php';

Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array('cache' => TWIG_CACHE));



$s = $_COOKIE['sessid'];
if ($s && strlen($s) == 64 && sessionActive($s)) refreshSession($s);
$se = $_GET['instance'];
$il = array('register', 'login', 'game', 'about');
$in = in_array($se, $il) ? $se : DEFAULT_INSTANCE;
$ca = array(
    'instance' => $in,
    'admin' => userPermissions($s) && sessionActive($s),
    'loggedIn' => sessionActive($s),
    'login' => userBySession($s),
    'mail_count' => 0,
);

if ($se) {
   
   if($se[strlen($se)-1] == '/') $se = substr($se, 0, strlen($se)-1);
   
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
      $ca['title'] = 'Регистрация';
      $ca['invalidLogin'] = !correctUserName($u) && $_POST; // логин хуйня
      $ca['invalidPass'] = !correctUserPassword($p) && $_POST; // тут хуйня
      $ca['loginIsBusy'] = userExists($u) && $_POST; // логин занят
      $ca['user'] = $u;
      $ca['pass'] = $p;
      $ca['error'] = $error;
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
      $ca['title'] = 'Вход';
      $ca['user'] = $u;
      $ca['error'] = $error;
   }
   /******************* login ***********************/
   
   /******************* game ***********************/
   elseif ($se == 'game') {
      if ($s && strlen($s)==64 && sessionActive($s) ) { refreshSession($s); }
      else { redirect('login'); die; }

      $ca['title'] = 'Игра';
      $ca['location_name'] = currentLocationTitle($s);
      $ca['area_name'] = currentAreaTitle($s);
      $ca['pic'] = 'img/sasuke.jpeg';
      $ca['description'] = currentLocationDescription($s);
      $ca['ways'] = allowedZones($s);
      $ca['players_list'] = usersOnLocation($s);      
   }
   /******************* game ***********************/
   
   /******************* moving ***********************/
   elseif ($se == 'go') {
      if ($to = $_GET['to']) {
         changeLocation($s, $to);
         redirect('game');
         die;
      }
   }
   /******************* moving ***********************/
}
elseif (defined('DEFAULT_INSTANCE')) redirect(DEFAULT_INSTANCE);


echo $twig->render( $in.'.twig', $ca );

$time_end = microtime(true);
echo "\n<!-- Done in " . ( ($time_end - $time_start) * 1000) . ' milliseconds -->';
?>