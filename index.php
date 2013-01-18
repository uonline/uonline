<?php

///// Load Twig. (Don't touch.)
require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
	// UNCOMMENT LATER
   // 'cache' => './templates_cache',
   'cache' => false,
));
///// Do some actions.

require_once('utils.php'); $s = $_COOKIE['sessid'];
if ( $s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
//insertEncoding('utf-8');
//include('inc/index');


///// And render.
echo $twig->render('index.twig', array(
	'title' => 'Well',
	'admin' => false,
	'loggedIn' => sessionActive($s),
	'login' => userBySession($s)
));

?>
