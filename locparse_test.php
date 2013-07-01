<?php

require_once './phpunit/vendor/autoload.php';
require_once './locparse.php';

class ParserTest extends PHPUnit_Framework_TestCase {

	function cleanup() {
		if (file_exists("./test")) rmdirr("./test");
	}

	public function testFirst() {
		$my = new Parser();
		$this->cleanup();
		mkdir("./test");
		$fp = fopen('./test/test.ht.md', 'w');
		fwrite($fp, "

# Кронт

Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - bluestreet

");
		fclose($fp);
		$my->processMap("./test/test.ht.md", "kront", "Кронт");
		$this->assertEquals($my->areas[0]->description, "Большой и ленивый город.

Здесь убивают слоников и разыгрывают туристов.");
		$this->assertEquals($my->locations[0]->name, "Голубая улица");
		$this->assertEquals($my->locations[0]->label, "kront/bluestreet");
		$this->assertEquals($my->locations[0]->description, "Здесь сидят гомосеки.");
		$this->assertEquals($my->locations[0]->actions["Пойти на Зелёную улицу"], "kront/greenstreet");
		$this->assertEquals($my->locations[1]->name, "Зелёная улица");
		$this->assertEquals($my->locations[1]->label, "kront/greenstreet");
		$this->assertEquals($my->locations[1]->description, "Здесь посажены деревья.\n\nИ грибы.\n\nИ животноводство.");
		$this->assertEquals($my->locations[1]->actions["Пойти на Голубую улицу"], "kront/bluestreet");
		$this->cleanup();
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

");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
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
		$this->assertEquals(2, count($my->locations));
		$this->assertEquals($my->locations[0]->label, "kront-outer/bluestreet");
		$this->assertEquals($my->locations[0]->description, "Здесь сидят гомосеки.");
		$this->assertEquals($my->locations[0]->actions["Пойти на Зелёную улицу"], "kront-outer/greenstreet");
		$this->assertEquals($my->locations[1]->name, "Зелёная улица");
		$this->assertEquals($my->locations[1]->label, "kront-outer/greenstreet");
		$this->assertEquals($my->locations[1]->description, "Здесь посажены деревья.\n\nИ грибы.\n\nИ животноводство.");
		$this->assertEquals($my->locations[1]->actions["Пойти на Голубую улицу"], "kront/bluestreet");
		$this->assertEquals($my->locations[1]->actions["Пойти на другую Голубую улицу"], "kront-outer/bluestreet");
		$this->cleanup();
	}
}

function rmdirr($dirname)
{
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
