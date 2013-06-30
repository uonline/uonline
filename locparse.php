<?php

	//$areas, $locations;

	class Area {
		public $label, $name, $id;
	}
	class Location {
		public $label, $name, $description, $actions, $id;
	}

	class Parser {

		public $areas, $locations;

		function processDir($dir, $previousLabel, $root) {
			if (!$root) {
				$a = new Area();
				$a->label = split (split("/", $dir)[0], " - ")[1];
				if ($previousLabel != null) $a->label = $previousLabel."-".$a->label;
				$a->name = $dir.split("/")[1].split(" - ")[0];
				$areas[count($areas)] = $a;

				processMap($dir."/map.ht.md", $a->label, $a->name);
			}
			foreach (dirEntries($dir, SpanMode.shallow) as $name)	{
				if (isDir($name)) {
					if ($root) {
						processDir($name, null, false);
					}
					else {
						processDir($name, end($areas)->label, false);
					}
				}
			}
		}

		function processMap($filename, $areaLabel, $areaName) {
			foreach(readText(filename).split("\n") as $s) {
				if (startsWith($s, "# ")) {
					assert(substr($s, 2) == $areaName);
				}
				else if (startsWith(s, "### ")) {
					$locations[] = new Location();
					$tmp = substr($s, 4);
					end($locations)->name = $tmp.split(" - ")[0];
					end($locations)->label = $areaLabel . "/" . $tmp.split(" - ")[1];
				}
				else if (startsWith($s, "* ")) {
					$tmp = substr($s, 2);
					$tmpAction = $tmp.split(" - ")[0];
					$tmpTarget = $tmp.split(" - ")[1];
					if ($tmpTarget.indexOf('/') == -1) $tmpTarget = $areaLabel . "/" . $tmpTarget;
					end($locations)->actions[$tmpAction] = $tmpTarget;
				}
				else if ((count($locations) == 0) && (strlen($s)== 0)) {
					// do nothing
				}
				else {
					end($locations)->description .= $s;
					end($locations)->description .= "\n";
				}
			}
			foreach ($locations as $l) {
				$l->description = trim($l->description);
			}
		}

		function main($args) {
			writeln("Everything is ok.");
			return 0;
		}

		function cleanup() {
			if (exists("./test")) rmdirRecurse("./test");
			$areas = [];
			$locations = [];
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
	}
?>
