<?php

require_once('utils.php');

mysqlConnect();
 
mysql_query('DROP DATABASE '.mysql_base);

echo mysql_error() ? '<span style="color: red">Cleanup error.</span>' : 'Cleanup success.';

?>