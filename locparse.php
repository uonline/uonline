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

if (isset($argv)) {
	if (array_key_exists(1, $argv) && ($argv[1] == "--validate" || $argv[1] == "-v")) {
		$p = new Parser();
		if (!(array_key_exists(2, $argv) && get_path($argv[2]))) die("Path not exists.");
		$p->processDir(get_path($argv[2]), null, true);
		echo "\n".report($p)."\n";
	}
	else if (array_key_exists(1, $argv) && ($argv[1] == "--export" || $argv[1] == "-e")) {
		$p = new Parser();
		if (!(array_key_exists(2, $argv) && get_path($argv[2]))) die("Path not exists.");
		$p->processDir(get_path($argv[2]), null, true);
		echo "\n".report($p)."\n";

		$i = new Injector($p->areas, $p->locations);
		$i->inject();
	}
	else if (array_key_exists(1, $argv) && $argv[1] == "--help") die(help());
}

function report($p) {
	return
		"found areas: ".count($p->areas)."\n".
		"found locations: ".count($p->locations->locations);
}

function get_path($p) {
	if (is_dir($p) && is_dir(__DIR__."/".$p)) return $p;
	else if (is_dir(__DIR__."/".$p)) return __DIR__."/".$p;
	else if (is_dir($p)) return $p;
	else return false;
}

function help() {
	return
	"[ --validate | --export ] path";
}

class Area {
	public $label, $name, $description, $id, $file;

	public function &__construct($label = "", $name = "", $description = "") {
		if (!$this->label) $this->label = $label;
		if (!$this->name) $this->name = $name;
		if (!$this->description) $this->description = $description;
		if (!$this->id) $this->id = round(abs(crc32($label))/2);
		return $this;
	}
}

class Location {
	public $label, $name, $description = "", $actions = array(), $area, $id, $goto, $file, $isDefault, $line, $string;

	public function &__construct($label = "", $name = "", $area = null, $description = "", $actions = "") {
		if (!$this->label) $this->label = $label;
		if (!$this->name) $this->name = $name;
		if (!$this->description) $this->description = $description;
		if (!$this->actions) $this->actions = $actions;
		if (!$this->area) $this->area = $area;
		if (!$this->id) $this->id = round(abs(crc32($label))/2);
		if ($this->area && isset($this->area->file)) $this->file = $area->file;
		return $this;
	}
}

class Locations {
	public $locations = array();
	public $links = array();
	public $ids = array();

	public function count() {
		return count($this->locations);
	}

	public function push($loc) {
		// fatal error #7
		if (array_key_exists($loc->label, $this->links)) fileFatal ("such location already exists", $loc->file, $loc->line, $loc->string);
		$this->links[$loc->label] = $loc->id;
		$this->ids[$loc->id] = $loc;
		$this->locations[] = $loc;
	}

	public function get($ind) {
		return $this->locations[$ind];
	}

	public function getById($id) {
		return $this->ids[$id];
	}

	public function last() {
		return end($this->locations);
	}

	public function finInit() {
		$this->trimDesc();
		$this->linkage();
	}

	public function linkage() {
		$hasDefault = false;
		foreach ($this->locations as $loc) {
			$goto = array(); $tmp = array(); $warn9 = false;
			foreach ($loc->actions as $v) {
				// fatal error #1
				if (!array_key_exists($v['target'], $this->links)) fileFatal("required location not exists", $loc->file, $v['line'], $v['string']);
				$goto[] = $v['action'] . "=" . $this->links[$v['target']];
				if (in_array($this->links[$v['target']], $tmp)) $warn9 = true;
				$tmp[] = $this->links[$v['target']];
			}
			// warning #9
			if ($warn9) fileWarning("such target already exists", $loc->file, $v['line'], $v['string']);
			$loc->goto = implode($goto, "|");
			$hasDefault = $loc->isDefault || $hasDefault;
		}
		// fatal error #6
		if (!$hasDefault) fileFatal ("default location is not set");
	}

	public function trimDesc() {
		foreach ($this->locations as $l) {
			$l->description = trim($l->description);
		}
	}

	public function &__construct() {
		return $this;
	}
}

	function fileWarning($warning, $filename, $line, $str = null) {
		echo
			"Warning: {$warning}\n".
			(($str !== null) ? "    {$str}\n" : "").
			"    line {$line} in {$filename}\n";
	}

	function fileFatal($warning, $filename = null, $line = 0, $str = null) {
		echo
			"Fatal: {$warning}\n".
			(($str !== null) ? "    {$str}\n" : "").
			(($filename !== null) ? "    line {$line} in {$filename}\n" : "");
		throw new InvalidArgumentException($warning);
	}

class Parser {

	public $areas = array(), $locations;

	function processDir($dir, $previousLabel, $root) {
		if ($root === false) {
			$splittedStr = explode(" - ", myexplode("/", $dir, -1));
			// fatal error #4
			if (!array_key_exists(1, $splittedStr)) fileFatal("can't find label of area", $dir);
			$label = $splittedStr[1];
			if ($previousLabel != null) $label = $previousLabel."-".$label;
			$name = $splittedStr[0];
			$this->areas[] = new Area(iconv(mb_detect_encoding($label, "utf-8, cp1251"), 'utf-8', $label), iconv(mb_detect_encoding($name, "utf-8, cp1251"), 'utf-8', $name));
			end($this->areas)->file = $dir."/map.ht.md";

			$this->processMap($dir."/map.ht.md", end($this->areas));
		}
		$myDirectory=opendir($dir);
			while($name=readdir($myDirectory)) {
			if (is_dir($dir.'/'.$name) && ($name != ".") && ($name != "..") && !startsWith($name, ".")) {
				if ($root) {
					$this->processDir($dir.'/'.$name, null, false);
				}
				else {
					$this->processDir($dir.'/'.$name, end($this->areas)->label, false);
				}
			}
		}
		if ($root) $this->locations->finInit();
	}

	function processMap($filename, $area) {
		$inLocation = false; $areaParsed = null;
		foreach(explode("\n", str_replace("\r\n", "\n", file_get_contents($filename))) as $k => $s) {
			$k++;
			// warning #1
			if (preg_match('/^#[^# ].+/', $s)) {
				fileWarning("missing space after '#'",$filename,$k,$s);
			}
			// warning #2
			if (preg_match('/^###[^ ].+/', $s)) {
				fileWarning("missing space after '###'",$filename,$k,$s);
			}
			// warning #3
			if (preg_match('/^\\*[^ \\*].+/', $s)) {
				fileWarning("missing space after '*'",$filename,$k,$s);
			}
			// warning #4
			if (preg_match('/^\\s+$/', $s)) {
				fileWarning("string with spaces only",$filename,$k);
			}
			// warning #5
			if (preg_match('/[^\\s]\\s+$/', $s)) {
				fileWarning("string ends with spaces",$filename,$k,$s);
			}
			// warning #6
			if (preg_match('/^\\s+[^\\s]/', $s)) {
				fileWarning("string starts with spaces",$filename,$k,$s);
			}
			// warning #7
			if (!$areaParsed && !startsWith($s, "# ") && strlen($s)) {
				fileWarning("non-empty string before area header",$filename,$k,$s);
			}

			if (startsWith($s, "# ")) {
				// fatal error #5
				$areaParsed = substr($s, 2);
				if ($areaParsed != $area->name) fileFatal("area's names from directory and file not equals",$filename,$k,$s);
			}
			else if (startsWith($s, "### ")) {
				$inLocation = true;
				$tmp = substr($s, 4);
				preg_match('/^(.+)(?: `)(.+)?(?=`)/', $tmp, $matches);
				// fatal error #3
				if (!array_key_exists(2, $matches)) fileFatal("can't find label of location",$filename,$k,$s);
				$l = new Location($area->label . "/" . $matches[2], $matches[1], $area);
				$l->isDefault = preg_match('/` \\(default\\)/', $tmp);
				$l->string = $s;
				$l->line = $k;
				$this->locations->push($l);
			}
			else if (startsWith($s, "* ")) {
				$tmp = substr($s, 2);
				preg_match('/^(.+)(?: `)(.+)?(?=`)/', $tmp, $matches);
				$tmpAction = array_key_exists(1, $matches) ? $matches[1] : null;
				$tmpTarget = array_key_exists(2, $matches) ? $matches[2] : null;
				// fatal error #2
				if (!$tmpTarget) fileFatal("can't find target of transition",$filename,$k,$s);
				// warning #8
				if (endsWith($tmpAction, ".")) {
					fileWarning("dot after transition",$filename,$k,$s);
				}
				if (strpos($tmpTarget, '/') === false) $tmpTarget = $area->label . "/" . $tmpTarget;
				$this->locations->last()->actions[] = array(
					'action' => $tmpAction,
					'target' => $tmpTarget,
					'string' => $s,
					'line' => $k,
				);
			}
			else {
				if ($inLocation) {
					$this->locations->last()->description .= $s."\n";
				}
				else {
					end($this->areas)->description .= $s."\n";
				}
			}
		}
		foreach ($this->areas as $a) {
			$a->description = trim($a->description);
		}
	}

	public function &__construct() {
		$this->locations = new Locations();
		return $this;
	}
}

class Injector {

	public $areas, $locations;

	public function &__construct($areas, $locations) {
		$this->areas = $areas;
		$this->locations = $locations;
		return $this;
	}

	public function inject($host = MYSQL_HOST, $user = MYSQL_USER, $pass = MYSQL_PASS, $base = MYSQL_BASE) {
		$conn = mysqli_connect($host, $user, $pass);
		mysqli_select_db($conn, $base);

		foreach ($this->areas as $v) {
			$r = mysqli_query($conn,
							"REPLACE `areas`".
							"(`title`, `description`, `id`)".
							"VALUES ('".
								mysqli_real_escape_string($conn, $v->name)."', '".
								mysqli_real_escape_string($conn, $v->description)."', ".
								mysqli_real_escape_string($conn, $v->id).")");
			if (!$r) echo($conn->error);
		}
		foreach ($this->locations->locations as $v) {
			$r = mysqli_query($conn,
							'REPLACE `locations`'.
							'(`title`, `goto`, `description`, `id`, `area`, `default`)'.
							'VALUES ("'.
								mysqli_real_escape_string($conn, $v->name).'", "'.
								mysqli_real_escape_string($conn, $v->goto).'", "'.
								mysqli_real_escape_string($conn, $v->description).'", "'.
								mysqli_real_escape_string($conn, $v->id).'", '.
								mysqli_real_escape_string($conn, $v->area->id).', '.
								( (int) $v->isDefault ).')');
			if (!$r) echo($conn->error);
			$r = $conn->query("SELECT * FROM `locations` WHERE `id` = $v->id");
			if (!$r) echo("export location \"$v->name - $v->label\" failed");
		}
	}
}

function startsWith($haystack, $needle) {
	return !strncmp($haystack, $needle, strlen($needle));
}

function endsWith($haystack, $needle) {
	$length = strlen($needle);
	if ($length == 0) {
		return true;
	}
	return (substr($haystack, -$length) === $needle);
}

function myexplode($pattern , $string, $index) {
	$tmp = explode($pattern, $string);
	if ($index == -1) $index = count($tmp) - 1;
	return array_key_exists($index, $tmp) ? $tmp[$index] : false;
}

?>
