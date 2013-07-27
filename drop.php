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

$HEAD = $BODY = '';

if ($_POST) {
	if ($_POST['ad_pass'] == ADMIN_PASS) {
		mysqlDelete();
		mysql_error() ? dropError() : dropSuccess();
	}
	else {
		wrongPass();
		fofForm();
	}
}
else {
	fofForm();
}

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');








function dropError() {
	global $BODY, $HEAD;
	$HEAD .= '<meta http-equiv="refresh" content="3;url=drop.php">';
	$BODY .= '<span style="color: red">Ошибка.</span>';
}

function dropSuccess() {
	global $BODY, $HEAD;
	$HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
	$BODY .= 'Успех.';
}


function wrongPass() {
	global $BODY, $HEAD;
	$HEAD .= '<meta http-equiv="refresh" content="3;url=drop.php">';
	$BODY .= '<span style="color: red">Пароль неверный.</span><br/>';
}

function fofForm() {
	global $BODY;
	$BODY .=
	'<form method="post" action="drop.php">'.
	'Удаление базы данных.<br/>'.
	'Административный пароль: <input name="ad_pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'" /><br/>'.
	'<input type="submit" value="Удалить" /><br/>';
}

?>
