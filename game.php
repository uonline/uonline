<?php

$time_start = microtime(true);

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
   //'cache' => './templates_cache', // UNCOMMENT LATER
   'cache' => false,
));


require_once('utils.php'); $s = $_COOKIE['sessid'];
if ($s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
else { header('Location: login.php'); die; }

if ($_GET && $to = $_GET['to']) {
    changeLocation($s, $to);
}


echo $twig->render('game.twig', array(
   'location_name' => currentLocationTitle($s),
   'area_name' => currentAreaTitle($s),
   'pic' => 'img/sasuke.jpeg',
   'description' => currentZoneDescription($s),
   'ways' => allowedZones($s),
   'players_list' => array( array( id => idBySession($s), name => userBySession($s) ) ),
   
   'admin' => false,
   'loggedIn' => sessionActive($s),
   'login' => userBySession($s),
   'mail_count' => 0,
   'file' => fileFromPath(__FILE__),
     
   'title' => 'Игра',
));

$time_end = microtime(true);
echo "\n<!-- Done in ".( ($time_end - $time_start) *1000).' milliseconds -->';

?>
