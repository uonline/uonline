<?php


/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


if (!file_exists('keyring')) die("Fatal error: keyring is missing.<br />\nCreate a file named 'keyring' in the project root using following format:<br />\nhost|username|password|database|cache (on/off)\n");
$keyring = trim(file_get_contents('keyring'));
$keyring_array = explode("|", $keyring);
if (count($keyring_array)===6) die("Fatal error: keyring uses old format. Please remove admin password from it.\n");
list($host, $user, $pass, $base, $cache) = $keyring_array;

// server
define('MYSQL_HOST', $host);
define('MYSQL_USER', $user);
define('MYSQL_PASS', $pass);
define('MYSQL_BASE', $base);
define('SESSION_LENGTH', 64);
define('SESSION_TIMEEXPIRE', 3600); //in seconds
define('DEFAULT_CHARSET', 'utf-8');
//define('BASE_OUTDATED', getNewHash() !== getHash());

// layout
define('DEFAULT_INSTANCE_FOR_GUESTS', '/about/');
define('DEFAULT_INSTANCE_FOR_USERS', '/game/');
define('TWIG_CACHE', $cache === 'on' ? './templates_cache' : false);

//game
define('EXP_MAX_START', 1000);
define('EXP_STEP', 1000);

?>
