<?php

require_once('utils.php'); $s = $_COOKIE['sessid'];
if ( $s && strlen($s)==64 && sessionActive($s) ) refreshSession($s);
insertEncoding('utf-8');
include('inc/index');

?>