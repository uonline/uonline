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

require_once './config.php';

if (isset($argv) && array_key_exists(1, $argv)) {
	$p = new Parser();
	$p->processDir(__DIR__."/".$argv[1], null, true);

	$i = new Injector($p->areas, $p->locations);
	$i->inject();
}

class Area {
	public $label, $name, $description, $id;

	public function &__construct($label = "", $name = "", $description = "") {
		if (!$this->label) $this->label = $label;
		if (!$this->name) $this->name = $name;
		if (!$this->description) $this->description = $description;
		if (!$this->id) $this->id = abs(crc32($label));
		return $this;
	}
}

class Location {
	public $label, $name, $description = "", $actions, $area, $id;

	public function &__construct($label = "", $name = "", $area = null, $description = "", $actions = "") {
		if (!$this->label) $this->label = $label;
		if (!$this->name) $this->name = $name;
		if (!$this->description) $this->description = $description;
		if (!$this->actions) $this->actions = $actions;
		if (!$this->area) $this->area = $area;
		if (!$this->id) $this->id = abs(crc32($label));
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

	public function unlink($label) {
		return $this->links[$label];
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

class Parser {

	public $areas = array(), $locations;

	function processDir($dir, $previousLabel, $root) {
		if ($root === false) {
			$splittedDir = explode("/", $dir);
			$splittedStr = explode(" - ", $splittedDir[count($splittedDir)-1]);
			$label = $splittedStr[1];
			if ($previousLabel != null) $label = $previousLabel."-".$label;
			$name = $splittedStr[0];
			$this->areas[] = new Area(iconv(mb_detect_encoding($label, "utf-8, cp1251"), 'utf-8', $label), iconv(mb_detect_encoding($name, "utf-8, cp1251"), 'utf-8', $name));

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
	}

	function processMap($filename, $area) {
		$inLocation = false;
		foreach(explode("\n", str_replace("\r\n", "\n", file_get_contents($filename))) as $s) {
			if (startsWith($s, "# ")) {
				assert(substr($s, 2) == $area->name);
			}
			else if (startsWith($s, "### ")) {
				$inLocation = true;
				$tmp = substr($s, 4);
				$l = new Location($area->label . "/" . myexplode(" - ", $tmp, 1), myexplode(" - ", $tmp, 0), $area);
				$this->locations->push($l);
			}
			else if (startsWith($s, "* ")) {
				$tmp = substr($s, 2);
				$tmpAction = myexplode(" - ", $tmp, 0);
				$tmpTarget = myexplode(" - ", $tmp, 1);
				if (strpos($tmpTarget, '/') === false) $tmpTarget = $area->label . "/" . $tmpTarget;
				$this->locations->last()->actions[$tmpAction] = $tmpTarget;
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
		$this->locations->trimDesc();
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
			mysqli_query($conn,
							"REPLACE `areas`".
							"(`title`, `description`, `id`)".
							"VALUES ('".
								mysqli_real_escape_string($conn, $v->name)."', '".
								mysqli_real_escape_string($conn, $v->description)."', ".
								mysqli_real_escape_string($conn, $v->id).")");
		}
		foreach ($this->locations->locations as $v) {
			$goto = array();
			foreach ($v->actions as $k1 => $v1) {
				$goto[] = $k1."=".$this->locations->unlink($v1);
			}
			mysqli_query($conn,
							'REPLACE `locations`'.
							'(`title`, `goto`, `description`, `id`, `area`, `default`)'.
							'VALUES ("'.
								mysqli_real_escape_string($conn, $v->name).'", "'.
								mysqli_real_escape_string($conn, implode($goto, "|")).'", "'.
								mysqli_real_escape_string($conn, $v->description).'", "'.
								mysqli_real_escape_string($conn, $v->id).'", '.
								mysqli_real_escape_string($conn, $v->area->id).', 0)');
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
	return $tmp[$index];
}

?>
