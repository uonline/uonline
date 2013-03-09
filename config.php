<?php

$keyring = file_exists('keyring') ? file_get_contents('keyring') : 0;
if ($keyring) { $key = explode("|", trim($keyring)); list($host, $user, $pass, $base, $admpass) = $key; }
else { $host = 'localhost'; $user = 'root'; $pass = ''; $base = 'universe'; $admpass = 'clearpass'; }


// server
define('MYSQL_HOST', $host);
define('MYSQL_USER', $user);
define('MYSQL_PASS', $pass);
define('MYSQL_BASE', $base);
define('ADMIN_PASS', $admpass);
define('SESSION_LENGTH', 64);
define('SESSION_TIMEEXPIRE', 3600); //in seconds
define('DEFAULT_CHARSET', 'utf-8');

// layout
define('DEFAULT_INSTANCE', 'about');
define('TWIG_CACHE', './templates_cache'); // false

//game
define('EXP_MAX_START', 1000);
define('EXP_STEP', 1000);

?>
