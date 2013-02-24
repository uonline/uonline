<?php

$keyring = file_exists('keyring') ? file_get_contents('keyring') : 0;
if ($keyring) { $key = explode("|", trim($keyring)); $host = $key[0]; $user = $key[1]; $pass = $key[2]; $base = $key[3]; $admpass = $key[4]; }
else { $host = 'localhost'; $user = 'root'; $pass = ''; $base = 'universe'; $admpass = 'clearpass'; }


// server
define('MYSQL_HOST', $host);
define('MYSQL_USER', $user);
define('MYSQL_PASS', $pass);
define('MYSQL_BASE', $base);
define('ADMIN_PASS', $admpass);
define('SESSION_LENGTH', 64);
define('DEFAULT_CHARSET', 'utf-8');

// layout
define('DEFAULT_INSTANCE', 'game');
define('TWIG_CACHE', false); // './templates_cache'

?>
