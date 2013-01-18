<?php

//require_once('utils.php'); $s = $_COOKIE['sessid'];
//if ( $s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
//insertEncoding('utf-8');
//include('inc/index');

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();

$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
	// UNCOMMENT LATER
    // 'cache' => './templates_cache',
));

echo $twig->render('index.twig', array('title' => 'Well'));

?>
