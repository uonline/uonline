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

require_once './yoficator/ReflectionTypeHint.php';
require_once './yoficator/UTF8.php';
require_once './yoficator/Text/Yoficator.php';
$yoficator = null;

function yof($s) {
	global $yoficator;
	if ($yoficator === null) $yoficator = new Text_Yoficator();
	return $yoficator->parse($s);
}


function tf($s) {
	$s = preg_replace('/^-(?= )|(?<= )-(?= )|---/', '&mdash;', $s); // em dash is "---" or " - "
	$s = preg_replace('/--/', '&ndash;', $s); // en dash is "--"
	$s = preg_replace('/(?:(?<=\D\d\d\d\d)|(?<=^\d\d\d\d))-(?:(?=\d\d\d\d\D)|(?=\d\d\d\d$))/', '&ndash;', $s); // en dash in year ranges, like "1941-1945"
	$s = preg_replace('/(?:^|(?<=(?:\d|\s)))-(?=\d)/', "&minus;", $s); // minus in negative numbers like "-2" and math expressions like "24-11=13"
	$s = preg_replace('/(?:"|\&quot\;)(?=[a-zA-Zа-яА-ЯйЙёЁру0-9])/', '&laquo;', $s);
	$s = preg_replace('/(?<=[a-zA-Zа-яА-ЯйЙёЁру0-9])(?:"|\&quot\;)/', '&raquo;', $s);
	return $s;
}

function nl2p($s) {
	$ar = explode("\n\n", $s);
	for ($s='', $i=0; $i<count($ar); $s.='<p>'.$ar[$i].'</p>', $i++);
	return $s;
}

?>