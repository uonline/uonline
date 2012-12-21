<?php

$domain = 'localhost';
$user = 'root';
$pass = '';

$db = 'universe';

@mysql_connect($domain, $user, $pass) or die('Error connecting to database: '.mysql_error());

mysql_query('DROP DATABASE '.$db);

?>