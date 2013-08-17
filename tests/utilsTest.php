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


require_once './config.php';
require_once './utils.php';

class UtilsTest extends PHPUnit_Framework_TestCase {

	public function testTf() {
		$this->assertEquals("&laquo;Чумный двор&raquo;", tf('"Чумный двор"'));
		$this->assertEquals("&laquo;Чумный двор&raquo;", tf('&quot;Чумный двор&quot;'));
		$this->assertEquals("Переход в &laquo;Чумный двор&raquo;", tf("Переход в \"Чумный двор\""));
		$this->assertEquals("Переход в &laquo;Чумный двор&raquo;", tf("Переход в &quot;Чумный двор&quot;"));
		$this->assertEquals("к &laquo;Чёрному ходу&raquo;.", tf('к "Чёрному ходу".'));
		$this->assertEquals("к &laquo;Чёрному ходу&raquo;.", tf('к &quot;Чёрному ходу&quot;.'));
		$this->assertEquals('&mdash; Ебу ли я гусей? Само собой.', tf('- Ебу ли я гусей? Само собой.'));
		$this->assertEquals('Хованский &mdash; пидорас и хуесос.', tf('Хованский - пидорас и хуесос.'));
		$this->assertEquals('Серп и молот&mdash;Карачарово', tf('Серп и молот---Карачарово'));
		$this->assertEquals('Серп и молот &mdash; Карачарово', tf('Серп и молот --- Карачарово'));
		$this->assertEquals('1941&ndash;1945', tf('1941--1945'));
		$this->assertEquals('4&minus;2=2', tf('4-2=2'));
		$this->assertEquals('&minus;2', tf('-2'));
		$this->assertEquals('Лучше оставьте &minus;2.', tf('Лучше оставьте -2.'));
		$this->assertEquals("&laquo;Гагарин-14&raquo;", tf('"Гагарин-14"'));
		$this->assertEquals("&laquo;Гагарин-14&raquo;", tf('&quot;Гагарин-14&quot;'));
		$this->assertEquals("&laquo;3 поросёнка&raquo;", tf('"3 поросёнка"'));
		$this->assertEquals("&laquo;3 поросёнка&raquo;", tf('&quot;3 поросёнка&quot;'));
		$this->assertEquals('Я бы назвал 1941&ndash;1945 годы.', tf('Я бы назвал 1941-1945 годы.'));
		$this->assertEquals('Сколько будет 1941&minus;19455?', tf('Сколько будет 1941-19455?'));
		$this->assertEquals('Сколько будет 19415&minus;1945?', tf('Сколько будет 19415-1945?'));
		$this->assertEquals('1941&ndash;1945 годы страшные.', tf('1941-1945 годы страшные.'));
		$this->assertEquals('Я думаю, 1941&ndash;1945', tf('Я думаю, 1941-1945'));
	}

	public function testLazyYofInit()
	{
		global $yoficator;
		$this->assertEquals(null, $yoficator);

		yof('something');
		$this->assertNotEquals(null, $yoficator);
		$tmpYof = $yoficator;

		yof('something else');
		$this->assertNotEquals(null, $yoficator);
		$this->assertEquals($tmpYof, $yoficator);
	}
}
