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
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


$keyring = file_exists('keyring') ? file_get_contents('keyring') : 0;
if ($keyring) { $key = explode("|", trim($keyring)); list($host, $user, $pass, $base, $admpass, $cache) = $key; }
else die('Keyring file missing.<br />Create file named "keyring" in the root with next content.<br />Format: host|user|pass|base|admpass|cache (on|off)');

// server
define('MYSQL_HOST', $host);
define('MYSQL_USER', $user);
define('MYSQL_PASS', $pass);
define('MYSQL_BASE', $base);
define('ADMIN_PASS', $admpass);
define('SESSION_LENGTH', 64);
define('SESSION_TIMEEXPIRE', 3600); //in seconds
define('DEFAULT_CHARSET', 'utf-8');
//define('BASE_OUTDATED', getNewHash() !== getHash());

// layout
define('DEFAULT_INSTANCE', 'about');
define('TWIG_CACHE', $cache === 'on' ? './templates_cache' : false);

//game
define('EXP_MAX_START', 1000);
define('EXP_STEP', 1000);

?>
