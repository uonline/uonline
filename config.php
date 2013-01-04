<?php


$keyring = file_exists('keyring') ? file_get_contents('keyring') : 0;

if ($keyring) {
   $key = explode("|", $keyring);
   $host = $key[0];
   $user = $key[1];
   $pass = $key[2];
   $base = $key[3];
}

define(mysql_host, $host ? $host : 'localhost');
define(mysql_user, $user ? $user : 'root');
define(mysql_pass, $pass ? $pass : '');
define(mysql_base, $base ? $base : 'universe');





?>