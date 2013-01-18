<?php

//require_once('utils.php'); $s = $_COOKIE['sessid'];
//if ( $s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
//insertEncoding('utf-8');
//include('inc/index');

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();

$loader = new Twig_Loader_String();
$twig = new Twig_Environment($loader);
echo $twig->render('Hello {{ name }}!', array('name' => 'works'));


?>