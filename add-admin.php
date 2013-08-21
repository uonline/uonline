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


require_once('utils.php');

if ($argc != 3) die("Usage: <username> <password>\n");

$u = $argv[1];
$p = $argv[2];

if (!correctUserName($u)) die("Incorrect username.\nMust be: 2-32 symbols, [a-zA-Z0-9а-яА-ЯёЁйЙру _-].\n");
if (userExists($u)) die("User `${u}` already exists.\n");
if (!correctPassword($p)) die("Incorrect password.\nMust be: 4-32 symbols, [!@#$%^&*()_+A-Za-z0-9].\n");

registerUser($u, $p, 65535);
echo "New admin `${u}` registered successfully.\n";
