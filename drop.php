<?php

require_once('utils.php');

mysqlConnect();

mysql_query('DROP DATABASE '.mysql_base);

?>