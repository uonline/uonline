<?php

//require_once './PHPUnit/Framework.php';
require_once './phpunit/vendor/autoload.php';
require_once './locparse.php';

class ParserTest extends PHPUnit_Framework_TestCase {
	public function testPower() {
		$my = new Parser();

		// first test
		$my->cleanup();
		mkdir("./test");
		$fp = fopen('./test/test.ht.md', 'w');
		fwrite($fp, "

# Кронт

### Голубая улица - bluestreet

Здесь сидят гомосеки.

* Пойти на Зелёную улицу - greenstreet

### Зелёная улица - greenstreet

Здесь посажены деревья.

И грибы.

И животноводство.

* Пойти на Голубую улицу - bluestreet

");

		$my->processMap("./test/test.ht.md", "kront", "Кронт");
		$this->assertEquals($my->locations[0]->name, "Голубая улица");
		$this->assertEquals($my->locations[0]->label, "kront/bluestreet");
		$this->assertEquals($my->locations[0]->description, "Здесь сидят гомосеки.");
		$this->assertEquals($my->locations[0]->actions["Пойти на Зелёную улицу"], "kront/greenstreet");
		$this->assertEquals($my->locations[1]->name, "Зелёная улица");
		$this->assertEquals($my->locations[1]->label, "kront/greenstreet");
		$this->assertEquals($my->locations[1]->description, "Здесь посажены деревья.

И грибы.

И животноводство.");
		$this->assertEquals($my->locations[1]->actions["Пойти на Голубую улицу"], "kront/bluestreet");
		$my->cleanup();
		writeln("passed");

		// second test
		mkdir("./test");
		mkdir("./test/Кронт - kront");
		$fp = fopen("./test/test.ht.md", 'w');
		fwrite($fp, "# Кронт");
		mkdir("./test/Кронт - kront/Окрестности Кронта - outer");
		$fp = fopen("./test/Кронт - kront/Окрестности Кронта - outer/map.ht.md", 'w');
		fwrite($fp, "

# Окрестности Кронта

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
		$my->processDir("./test", null, true);
		$this->assertEquals($my->areas[0]->name, "Кронт");
		$this->assertEquals($my->areas[0]->label, "kront");
		$this->assertEquals($my->areas[1]->name, "Окрестности Кронта");
		$this->assertEquals($my->areas[1]->label, "kront-outer");
		$this->assertEquals($my->locations[0]->label, "kront-outer/bluestreet");
		$this->assertEquals($my->locations[0]->description, "Здесь сидят гомосеки.");
		$this->assertEquals($my->locations[0]->actions["Пойти на Зелёную улицу"], "kront-outer/greenstreet");
		$this->assertEquals($my->locations[1]->name, "Зелёная улица");
		$this->assertEquals($my->locations[1]->label, "kront-outer/greenstreet");
		$this->assertEquals($my->locations[1]->description, "Здесь посажены деревья.

И грибы.

И животноводство.");
		$this->assertEquals($my->locations[1]->actions["Пойти на Голубую улицу"], "kront/bluestreet");
		$this->assertEquals($my->locations[1]->actions["Пойти на другую Голубую улицу"], "kront-outer/bluestreet");
		$my->cleanup();
		writeln("passed");
	}
}

?>
