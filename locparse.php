<?php

class Area {
	public $label, $name, $description = "", $id;

	public function &__construct($label, $name, $description = "") {
		$this->label = $label;
		$this->name = $name;
		$this->description = $description;
		$this->id = crc32($label);
		return $this;
	}
}

class Location {
	public $label, $name, $description = "", $actions, $area, $id;

	public function &__construct($label, $name, $description = "", $actions = "", $area = null) {
		$this->label = $label;
		$this->name = $name;
		$this->description = $description;
		$this->actions = $actions;
		$this->area = $area;
		$this->id = crc32($label);
		return $this;
	}
}

class Parser {

	public $areas = array(), $locations = array(), $hashes = array();

	function processDir($dir, $previousLabel, $root) {
		if ($root === false) {
			$splittedDir = explode("/", $dir);
			$splittedStr = explode(" - ", $splittedDir[count($splittedDir)-1]);
			$label = $splittedStr[1];
			if ($previousLabel != null) $label = $previousLabel."-".$label;
			$name = $splittedStr[0];
			$this->areas[] = new Area($label, $name);

			$this->processMap($dir."/map.ht.md", $a);
		}
		$myDirectory=opendir($dir);
			while($name=readdir($myDirectory)) {
			if (is_dir($dir.'/'.$name) && ($name != ".") && ($name != "..")) {
				if ($root) {
					$this->processDir($dir.'/'.$name, null, false);
				}
				else {
					$this->processDir($dir.'/'.$name, end($this->areas)->label, false);
				}
			}
		}
	}

	function processMap($filename, &$area) {
		$inLocation = false;
		foreach(explode("\n", str_replace("\r\n", "\n", file_get_contents($filename))) as $s) {
			if (startsWith($s, "# ")) {
				echo iconv("utf-8", "cp866",$area->name)."\n";
				echo substr($s, 2);
				echo($area->name);
//				assert(substr($s, 2), $area->name); //???
			}
			else if (startsWith($s, "### ")) {
				$inLocation = true;
				$tmp = substr($s, 4);
				$l = new Location($area->label . "/" . myexplode(" - ", $tmp, 1), myexplode(" - ", $tmp, 0));
				$this->locations[] = $l;
			}
			else if (startsWith($s, "* ")) {
				$tmp = substr($s, 2);
				$tmpAction = myexplode(" - ", $tmp, 0);
				$tmpTarget = myexplode(" - ", $tmp, 1);
				if (strpos($tmpTarget, '/') === false) $tmpTarget = $area->label . "/" . $tmpTarget;
				end($this->locations)->actions[$tmpAction] = $tmpTarget;
			}
			else {
				if ($inLocation) {
					end($this->locations)->description .= $s."\n";
				}
				else {
					end($this->areas)->description .= $s."\n";
				}
			}
		}
		foreach ($this->locations as $l) {
			$l->description = trim($l->description);
		}
		foreach ($this->areas as $a) {
			$a->description = trim($a->description);
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
