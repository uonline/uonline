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


class Area {
	public $label, $name, $description = "", $id;
}

class Location {
	public $label, $name, $description = "", $actions, $id;
}

class Parser {

	public $areas = array(), $locations = array();

	function processDir($dir, $previousLabel, $root) {
		if ($root === false) {
			$a = new Area();
			$splittedDir = explode("/", $dir);
			$splittedStr = explode(" - ", $splittedDir[count($splittedDir)-1]);
			$a->label = $splittedStr[1];
			if ($previousLabel != null) $a->label = $previousLabel."-".$a->label;
			$a->name = $splittedStr[0];
			$this->areas[] = $a;

			$this->processMap($dir."/map.ht.md", $a->label, $a->name);
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

	function processMap($filename, $areaLabel, $areaName) {
		$inLocation = false;
		foreach(explode("\n", str_replace("\r\n", "\n", file_get_contents($filename))) as $s) {
			if (startsWith($s, "# ")) {
				assert(substr($s, 2) == $areaName);
			}
			else if (startsWith($s, "### ")) {
				$inLocation = true;
				$this->locations[] = new Location();
				$tmp = substr($s, 4);
				end($this->locations)->name = myexplode(" - ", $tmp, 0);
				end($this->locations)->label = $areaLabel . "/" . myexplode(" - ", $tmp, 1);
			}
			else if (startsWith($s, "* ")) {
				$tmp = substr($s, 2);
				$tmpAction = myexplode(" - ", $tmp, 0);
				$tmpTarget = myexplode(" - ", $tmp, 1);
				if (strpos($tmpTarget, '/') === false) $tmpTarget = $areaLabel . "/" . $tmpTarget;
				end($this->locations)->actions[$tmpAction] = $tmpTarget;
			}
			else {
				if ($inLocation) {
					end($this->locations)->description .= $s;
					end($this->locations)->description .= "\n";
				}
				else {
					end($this->areas)->description .= $s;
					end($this->areas)->description .= "\n";
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
