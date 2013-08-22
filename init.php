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


require_once './utils.php';
require_once './locparse.php';


if ($argc === 1 || in_array("--help", $argv) || in_array("-h", $argv))
	die("Usage: [--database] [--tables] [--unify-validate] [--unify-export] [--optimize] [--test-monsters] [--drop]\n");

if (in_array("--info", $argv) || in_array("-i", $argv))
{
	$count = count(getMigrationFunctions());
	writeln('init.php with '.$count.' revision'.((($count % 10 === 1)&&($count !== 11))?'':'s').' on board.');
	writeln('Current revision is '.getCurrentRevision().
		' ('.(getNewestRevision() <= getCurrentRevision() ? 'up to date':'needs update').').');
	die;
}

writeln('Starting init.');
$init = new Init();
if (in_array("--database", $argv) || in_array("-d", $argv)) $init->database();
if (in_array("--tables", $argv) || in_array("-t", $argv)) $init->tables();
if (in_array("--unify-validate", $argv) || in_array("-uv", $argv)) $init->unifyValidate();
if (in_array("--unify-export", $argv) || in_array("-ue", $argv)) $init->unifyExport();
if (in_array("--test-monsters", $argv) || in_array("-tm", $argv)) $init->testMonsters();
if (in_array("--optimize", $argv) || in_array("-o", $argv)) $init->optimize();
if (in_array("--drop", $argv) || in_array("-dr", $argv)) $init->drop();
writeln('Done.');


class Init {
	public $mysqli;

	function connect() {
		action('Connecting to database');
		$this->mysqli = mysqliConnect();
		result($this->mysqli && $this->mysqli->errno === 0 ? 'ok' : 'error');
	}

	function database() {
		action('Creating database `'.MYSQL_BASE.'`');
		$this->mysqli = mysqliInit();
		result($this->mysqli && $this->mysqli->errno === 0 ? 'ok' : 'error');
	}

	function tables() {
		$this->connect();
		section('Migrating tables');
		writeln('Current revision is '.getCurrentRevision().'.');
		if (getNewestRevision() <= getCurrentRevision())
		{
			writeln('Already up to date.');
		}
		else
		{
			migrate(getNewestRevision());
		}
		endSection();
	}

	function unifyValidate() {
		section('Validating unify');
		$p = new Parser();
		if (!get_path("unify")) die("Path not exists.");
		$p->processDir(get_path("unify"), null, true);
		endSection();
	}

	function unifyExport() {
		section('Exporting unify');
		$p = new Parser();
		if (!get_path("unify")) die("Path not exists.");
		$p->processDir(get_path("unify"), null, true);

		(new Injector($p->areas, $p->locations))->inject();
		endSection();
	}

	function optimize() {
		section('Optimizing tables');
		$this->connect();
		$q = $this->mysqli->query(
				"SELECT `TABLE_NAME` ".
				"FROM `information_schema`.`TABLES` ".
				"WHERE `TABLE_SCHEMA`='".MYSQL_BASE."'");
		while ($t = $q->fetch_array()) {
			action('Optimizing table `'.$t[0].'`');
			$q1 = $this->mysqli->query("OPTIMIZE TABLE `$t[0]`");
			$other = array();
			for (;$r = $q1->fetch_assoc();) {
				if ($r["Msg_type"] === "status") {
					$status = $r["Msg_text"];
					continue;
				}
				if ($r["Msg_type"] && $r["Msg_text"]) $other[] = $r["Msg_type"].": ".$r["Msg_text"];
			}
			result(implode('; ', array_merge(array($status), $other)));
		}
		endSection();
	}

	function testMonsters() {
		$monsters = array(
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (1, 6, 774449300, 1, 1, NULL, 16)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (2, 5, 648737395, 1, 1, NULL, 5)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (3, 6, 580475724, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (4, 3, 571597042, 1, 1, NULL, 22)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (5, 4, 845588419, 1, 1, NULL, 11)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (6, 3, 446105458, 1, 1, NULL, 19)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (7, 1, 4642136, 1, 1, NULL, 10)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (8, 5, 29958182, 1, 1, NULL, 9)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (9, 7, 904434466, 1, 1, NULL, 13)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (10, 7, 288482442, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (11, 1, 77716864, 1, 1, NULL, 6)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (12, 2, 701741103, 1, 1, NULL, 17)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (13, 5, 744906885, 1, 1, NULL, 22)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (14, 4, 744906885, 1, 1, NULL, 6)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (15, 7, 4642136, 1, 1, NULL, 8)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (16, 2, 1054697917, 1, 1, NULL, 7)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (17, 6, 833637588, 1, 1, NULL, 10)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (18, 6, 29958182, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (19, 6, 774449300, 1, 1, NULL, 12)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (20, 4, 744906885, 1, 1, NULL, 8)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (21, 5, 446105458, 1, 1, NULL, 22)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (22, 5, 288482442, 1, 1, NULL, 17)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (23, 1, 4642136, 1, 1, NULL, 8)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (24, 7, 29958182, 1, 1, NULL, 16)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (25, 5, 774449300, 1, 1, NULL, 15)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (26, 7, 1054697917, 1, 1, NULL, 20)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (27, 5, 723001325, 1, 1, NULL, 16)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (28, 4, 571597042, 1, 1, NULL, 23)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (29, 3, 845588419, 1, 1, NULL, 14)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (30, 5, 288482442, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (31, 4, 701741103, 1, 1, NULL, 6)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (32, 2, 77716864, 1, 1, NULL, 15)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (33, 7, 701741103, 1, 1, NULL, 17)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (34, 7, 701741103, 1, 1, NULL, 22)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (35, 5, 772635195, 1, 1, NULL, 7)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (36, 6, 29958182, 1, 1, NULL, 21)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (37, 4, 29958182, 1, 1, NULL, 18)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (38, 1, 578736465, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (39, 4, 172926385, 1, 1, NULL, 25)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (40, 2, 744906885, 1, 1, NULL, 21)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (41, 5, 29958182, 1, 1, NULL, 21)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (42, 4, 723001325, 1, 1, NULL, 9)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (43, 1, 451777421, 1, 1, NULL, 8)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (44, 4, 29958182, 1, 1, NULL, 5)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (45, 4, 648737395, 1, 1, NULL, 24)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (46, 2, 723001325, 1, 1, NULL, 21)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (47, 2, 571597042, 1, 1, NULL, 24)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (48, 2, 288482442, 1, 1, NULL, 13)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (49, 2, 774449300, 1, 1, NULL, 8)",
			"REPLACE INTO `monsters` (`incarn_id`, `id`, `location`, `health`, `mana`, `effects`, `attack_chance`) VALUES (50, 6, 446105458, 1, 1, NULL, 19)"
		);
		$this->connect();

		action('Adding test monsters');
		foreach ($monsters as $v) {
			$this->mysqli->query($v);
			if ($this->mysqli->errno !== 0) {
				echo $this->err()."\n";
				return;
			}
		}
		result('ok');
	}

	function drop() {
		$this->connect();
		action('Dropping database `'.MYSQL_BASE.'`');
		mysqlDelete();
		if ($this->mysqli && $this->mysqli->errno === 0)
		{
			setRevision(0);
			result('ok');
		}
		else
		{
			result('error');
		}
	}
}
