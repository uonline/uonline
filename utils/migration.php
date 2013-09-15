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


function getMigrationFunctions() {
	return array (
		1 => function() {
			/************** uniusers ****************/
			addTable('uniusers', '(`id` INT AUTO_INCREMENT, PRIMARY KEY (`id`))');
			addColumn("uniusers", "location|INT DEFAULT 1");
			addColumn("uniusers", "permissions|INT DEFAULT 0");
			addColumn("uniusers", "user|TINYTEXT");
			addColumn("uniusers", "mail|TINYTEXT");
			addColumn("uniusers", "salt|TINYTEXT");
			addColumn("uniusers", "hash|TINYTEXT");
			addColumn("uniusers", "sessid|TINYTEXT");
			addColumn("uniusers", "sessexpire|DATETIME");
			addColumn("uniusers", "reg_time|DATETIME");

			addColumn("uniusers", "fight_mode|INT DEFAULT 0");
			addColumn("uniusers", "autoinvolved_fm|INT DEFAULT 0");
			addColumn("uniusers", "level|INT DEFAULT 1");
			addColumn("uniusers", "health|INT DEFAULT 200");
			addColumn("uniusers", "health_max|INT DEFAULT 200");
			addColumn("uniusers", "mana|INT DEFAULT 100");
			addColumn("uniusers", "mana_max|INT DEFAULT 100");
			addColumn("uniusers", "energy|INT DEFAULT 50");
			addColumn("uniusers", "power|INT DEFAULT 3");
			addColumn("uniusers", "defense|INT DEFAULT 3");
			addColumn("uniusers", "agility|INT DEFAULT 3"); //ловкость
			addColumn("uniusers", "accuracy|INT DEFAULT 3"); //точность
			addColumn("uniusers", "intelligence|INT DEFAULT 5"); //интеллект
			addColumn("uniusers", "initiative|INT DEFAULT 5"); //инициатива
			addColumn("uniusers", "exp|INT DEFAULT 0");
			addColumn("uniusers", "effects|TEXT");

			/************** locations ****************/
			addTable('locations', '(`id` INT, PRIMARY KEY (`id`))');
			addColumn("locations", "title|TINYTEXT");
			addColumn("locations", "goto|TINYTEXT");
			addColumn("locations", "description|TEXT");
			addColumn("locations", "area|INT");
			addColumn("locations", "picture|TINYTEXT");
			addColumn("locations", "default|TINYINT(1) DEFAULT 0");

			/************** areas ****************/
			addTable('areas', '(`id` INT, PRIMARY KEY (`id`))');
			addColumn("areas", "title|TINYTEXT");
			addColumn("areas", "description|TEXT");

			/************** monster_prototypes ****************/
			addTable('monster_prototypes', '(`id` INT AUTO_INCREMENT, PRIMARY KEY (`id`))');
			addColumn("monster_prototypes", "name|TINYTEXT");
			addColumn("monster_prototypes", "level|INT");
			addColumn("monster_prototypes", "power|INT");
			addColumn("monster_prototypes", "agility|INT");
			addColumn("monster_prototypes", "endurance|INT");
			addColumn("monster_prototypes", "intelligence|INT");
			addColumn("monster_prototypes", "wisdom|INT");
			addColumn("monster_prototypes", "volition|INT");
			addColumn("monster_prototypes", "health_max|INT");
			addColumn("monster_prototypes", "mana_max|INT");

			/************** monsters ****************/
			addTable('monsters', '(`incarn_id` INT AUTO_INCREMENT, PRIMARY KEY (`incarn_id`))');
			addColumn("monsters", "id|INT");
			addColumn("monsters", "location|INT");
			addColumn("monsters", "health|INT");
			addColumn("monsters", "mana|INT");
			addColumn("monsters", "effects|TEXT");
			addColumn("monsters", "attack_chance|INT");
		},
		2 => function() {
			/************** stats ****************/
			addTable('stats', '(`time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
			addColumn("stats", "gen_time|DOUBLE");
			addColumn("stats", "instance|TINYTEXT");
			addColumn("stats", "ip|TINYTEXT");
			addColumn("stats", "uagent|TINYTEXT");
			addColumn("stats", "url|TEXT");
		},
	);
}

function getNewestRevision() {
	$migrate = getMigrationFunctions();
	return max(array_keys($migrate));
}

function getCurrentRevision() {
	$r = file_exists('tablestate') ? trim(file_get_contents('tablestate')) : false;
	return (is_numeric($r) ? (int) $r : 0);
}

function setRevision($r) {
	$fp = fopen ("tablestate","w"); //открытие
	fputs($fp , $r ); //работа с файлом
	fclose ($fp); //закрытие
}

function migrate($revision) {
	$migrate = getMigrationFunctions();
	$currentRevision = getCurrentRevision(); // если файла-индекса не существует или в нём нет единственного числа, то 0
	if ($currentRevision < $revision)
	{
		foreach($migrate as $k => $v)
		{
			if ($k > $currentRevision)
			{
				section('Migrating from revision '.getCurrentRevision().' to '.$k);
				$v();
				setRevision($k);
				endSection();
			}
		}
	}
	else
	{
		writeln("Refused to migrate from revision {$currentRevision} to {$revision}.");
		return true;
	}
}

?>
