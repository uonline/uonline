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


require_once './locparse.php';
require_once './config.php';

class ParserTest extends PHPUnit_Framework_TestCase {

	function cleanup() {
		if (file_exists("./test"))
			rmdirr("./test");
	}

	public function testSecond() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->assertEquals(2, count($my->areas));
		$this->assertEquals($my->areas[0]->name, "Кронт");
		$this->assertEquals($my->areas[0]->label, "kront");
		$this->assertEquals($my->areas[0]->description, "Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.");
		$this->assertEquals($my->areas[1]->name, "Окрестности Кронта");
		$this->assertEquals($my->areas[1]->label, "kront-outer");
		$this->assertEquals($my->areas[1]->description, "Здесь темно.");

		$this->assertEquals(3, $my->locations->count());
		$this->assertEquals($my->locations->get(0)->label, "kront/bluestreet");
		$this->assertEquals($my->locations->get(0)->description, "Здесь стоят гомосеки и немного пидарасов.");
		$this->assertEquals($my->locations->get(0)->actions[0]['action'], "Пойти на Зелёную улицу");
		$this->assertEquals($my->locations->get(0)->actions[0]['target'], "kront-outer/greenstreet");
		$this->assertEquals($my->locations->get(0)->actions[1]['action'], "Пойти на Голубую улицу");
		$this->assertEquals($my->locations->get(0)->actions[1]['target'], "kront-outer/bluestreet");
		$this->assertEquals($my->locations->get(1)->label, "kront-outer/bluestreet");
		$this->assertEquals($my->locations->get(1)->description, "Здесь сидят гомосеки.");
		$this->assertEquals($my->locations->get(1)->actions[0]['action'], "Пойти на Зелёную улицу");
		$this->assertEquals($my->locations->get(1)->actions[0]['target'], "kront-outer/greenstreet");
		$this->assertEquals($my->locations->get(2)->name, "Зелёная улица");
		$this->assertEquals($my->locations->get(2)->label, "kront-outer/greenstreet");
		$this->assertEquals($my->locations->get(2)->description, "Здесь посажены деревья.\n\nИ грибы.\n\nИ животноводство.");
		$this->assertEquals($my->locations->get(2)->actions[0]['action'], "Пойти на Голубую улицу");
		$this->assertEquals($my->locations->get(2)->actions[0]['target'], "kront/bluestreet");
		$this->assertEquals($my->locations->get(2)->actions[1]['action'], "Пойти на другую Голубую улицу");
		$this->assertEquals($my->locations->get(2)->actions[1]['target'], "kront-outer/bluestreet");

		$this->assertEquals($my->areas[0], $my->locations->get(0)->area);
		$this->assertEquals($my->areas[1], $my->locations->get(1)->area);
		$this->assertEquals($my->areas[1], $my->locations->get(2)->area);

//		ini_set('error_reporting', E_ALL ^ E_DEPRECATED);
		$base = "test_".MYSQL_BASE;

		$conn = mysqli_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS);
		mysqli_query($conn, 'CREATE DATABASE IF NOT EXISTS `'.$base.'`');
		mysqli_select_db($conn, $base);
		mysqli_query($conn, 'CREATE TABLE `areas` (`title` TINYTEXT, `description` TEXT, `id` INT, PRIMARY KEY (`id`))');
		mysqli_query($conn, 'CREATE TABLE `locations` (`title` TINYTEXT, `goto` TINYTEXT, `description` TINYTEXT, `id` INT, `area` INT, `default` TINYINT(1) DEFAULT 0, PRIMARY KEY (`id`))');

		$injector = (new Injector($my->areas, $my->locations));
		$injector->inject(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, $base);

		// database areas assertion
		$this->assertEquals(2, $conn->query("SELECT count(*) FROM `areas`")->fetch_array()[0]);

		$qareas = $conn->query("SELECT `title` AS `name`, `id` AS `id`, `description` AS `description` FROM `areas` ORDER BY `id`");

		$a1 = $qareas->fetch_object("Area");
		$this->assertEquals("Кронт", $a1->name);
		//$this->assertEquals(53859108, $a1->id);
		$this->assertEquals("Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.", $a1->description);
		$this->assertNotEquals(null, $a1->id);
		$this->assertNotEquals(0, $a1->id);

		$a2 = $qareas->fetch_object("Area");
		$this->assertEquals("Окрестности Кронта", $a2->name);
		//$this->assertEquals(556987862, $a2->id);
		$this->assertEquals("Здесь темно.", $a2->description);
		$this->assertNotEquals(null, $a2->id);
		$this->assertNotEquals(0, $a2->id);

		$this->assertNotEquals($a1->id, $a2->id);


		// database locations assertion
		$this->assertEquals(3, $conn->query("SELECT count(*) FROM `locations`")->fetch_array()[0]);

		$qlocs = $conn->query("SELECT `title` AS `name`, `description` AS `description`, `goto` AS `goto`, `id` AS `id`, `area` AS `area` FROM `locations` ORDER BY `id`");

		$l1 = $qlocs->fetch_object("Location");
		$this->assertEquals("Другая голубая улица", $l1->name);
		$this->assertStringMatchesFormat("Пойти на Зелёную улицу=%d|Пойти на Голубую улицу=%d", $l1->goto);
		$this->assertEquals("Здесь стоят гомосеки и немного пидарасов.", $l1->description);
		//$this->assertEquals(392970597, $l1->id);
		//$this->assertEquals(53859108, $l1->area);
		$this->assertNotEquals(null, $l1->id);
		$this->assertNotEquals(0, $l1->id);

		$l2 = $qlocs->fetch_object("Location");
		$this->assertEquals("Голубая улица", $l2->name);
		$this->assertStringMatchesFormat("Пойти на Зелёную улицу=%d", $l2->goto);
		$this->assertEquals("Здесь сидят гомосеки.", $l2->description);
		//$this->assertEquals(740842744, $l2->id);
		//$this->assertEquals(556987862, $l2->area);
		$this->assertNotEquals(null, $l2->id);
		$this->assertNotEquals(0, $l2->id);

		$l3 = $qlocs->fetch_object("Location");
		$this->assertEquals("Зелёная улица", $l3->name);
		$this->assertStringMatchesFormat("Пойти на Голубую улицу=%d|Пойти на другую Голубую улицу=%d", $l3->goto);
		$this->assertEquals("Здесь посажены деревья.

И грибы.

И животноводство.", $l3->description);
		//$this->assertEquals(764833624, $l3->id);
		//$this->assertEquals(556987862, $l3->area);
		$this->assertNotEquals(null, $l3->id);
		$this->assertNotEquals(0, $l3->id);

		$this->assertNotEquals($l1->id, $l2->id);
		$this->assertNotEquals($l2->id, $l3->id);
		$this->assertNotEquals($l3->id, $l1->id);

		$conn->query("DROP DATABASE $base");
		$conn->close();

		$this->cleanup();
	}

	public function testWarning1() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта
#Место встречи изменить нельзя
Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: missing space after '#'\n    #Место встречи изменить нельзя\n    line 4 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md\n");

		$this->cleanup();
	}

	public function testWarning2() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта
###Место встречи изменить нельзя
Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: missing space after '###'\n    ###Место встречи изменить нельзя\n    line 4 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md\n");

		$this->cleanup();
	}

	public function testWarning3() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта
*Место встречи изменить нельзя
Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: missing space after '*'\n    *Место встречи изменить нельзя\n    line 4 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md\n");

		$this->cleanup();
	}

	public function testWarning4() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта
"."    "."
Здесь темно.
"."\t"."
### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: string with spaces only
    line 4 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md
Warning: string with spaces only
    line 6 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md
");

		$this->cleanup();
	}

	public function testWarning5() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

Здесь темно."." "."

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: string ends with spaces
    Здесь темно. "."
    line 5 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md
");

		$this->cleanup();
	}

	public function testWarning6() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

"." Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: string starts with spaces
     Здесь темно.
    line 5 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md
");

		$this->cleanup();
	}

	public function testWarning7() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "
Ня.
# Окрестности Кронта

Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: non-empty string before area header
    Ня.
    line 2 in ./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md
");

		$this->cleanup();
	}

	public function testWarning8() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront-outer/greenstreet
* Пойти на Голубую улицу. - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$my->processDir("./test", null, true);

		$this->expectOutputString("Warning: dot after transition
    * Пойти на Голубую улицу. - kront-outer/bluestreet
    line 14 in ./test/Кронт - kront/map.ht.md
");

		$this->cleanup();
	}

	public function testError1() {
		$my = new Parser();
		$this->cleanup();

		mkdir("./test");
		mkdir("./test/Кронт - kront");

		$fp = fopen("./test/Кронт - kront/map.ht.md", 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Другая голубая улица - bluestreet

Здесь стоят гомосеки и немного пидарасов.

* Пойти на Зелёную улицу - kront/greenstreet
* Пойти на Голубую улицу - kront-outer/bluestreet

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		fclose($fp);

		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

Здесь темно.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - kront/bluestreet
* Пойти на другую Голубую улицу - bluestreet

");
		fclose($fp);

		$this->setExpectedException("InvalidArgumentException", "required location not exists");

		$this->expectOutputString("Fatal: required location not exists
    * Пойти на Зелёную улицу - kront/greenstreet
    line 13 in ./test/Кронт - kront/map.ht.md
");

		$my->processDir("./test", null, true);

		$this->cleanup();
	}
/**/
}

function rmdirr($dirname) {
	// Sanity check
	if (!file_exists($dirname)) {
		return false;
	}

	// Simple delete for a file
	if (is_file($dirname) || is_link($dirname)) {
		return unlink($dirname);
	}

	// Loop through the folder
	$dir = dir($dirname);
	while (false !== $entry = $dir->read()) {
		// Skip pointers
		if ($entry == '.' || $entry == '..') {
			continue;
		}

		// Recurse
		rmdirr($dirname . DIRECTORY_SEPARATOR . $entry);
	}

	// Clean up
	$dir->close();
	return rmdir($dirname);
}

?>
