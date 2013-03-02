<?php

require_once('utils.php');

$HEAD = $BODY = '';

insertEncoding();

if ($_POST) {
   if ($_POST['pass'] === ADMIN_PASS) {

      echo '<style>h4, h5, h6 { margin: 0px; } h5 { margin-left: 10px; } h6 { margin-left: 20px; } .err { color: red; } .warn { color: #95CE58; } </style>';

      function ok() { return '<span>done</span>'; }
      function err() { global $err; $err++; return '<span class="err">error</span>'; }
      function warn() { global $warn; $warn++; return '<span class="warn">exists</span>'; }

      if ($_POST['createbases']) {
         echo '<h4>Создание баз данных ... ';
         mysqlInit();
         echo mysql_errno()===0?ok():err();
         echo '</h4><br />';
      }
      else {
         echo '<h4>Подключение к базам данных...';
         mysqlConnect();
         echo mysql_errno()===0?ok():err();
         echo '</h4><br />';
      }

      if ($_POST['createtables']) {
          $t = array(
             'uniusers' => '(`user` TINYTEXT, `mail` TINYTEXT, `salt` TINYTEXT, `hash` TINYTEXT, `sessid` TINYTEXT, `sessexpire` DATETIME, `reg_time` DATETIME, `id` INT AUTO_INCREMENT, `location` INT DEFAULT 1, /*`permissions` INT DEFAULT 0,*/ PRIMARY KEY  (`id`) )',
             'locations' => '(`title` TINYTEXT, `goto` TINYTEXT, `description` TINYTEXT, `id` INT, `super` INT, `default` TINYINT(1) DEFAULT 0, PRIMARY KEY (`id`))',
             'areas' => '(`title` TINYTEXT, `id` INT, PRIMARY KEY (`id`))',
          );
          foreach ($t as $k => $v) {
              echo '<h5>Создание таблицы `'.$k.'` ... ';
              $res = addTable($k, $v);
              echo $res === FALSE ? warn() : ($res === 0 ? ok() : err());
              echo '</h5>';
          }
          echo '<br />';
      }

      if ($_POST['updatetables']) {
      //{ {table => tableName, columns => { columnNname => columnOptions, ... } }, ... }
          $c = array(
              array(
                'table' => 'uniusers',
                'columns' => array(
                   'permissions' => 'INT AFTER `location`',
                   'level' => 'INT DEFAULT 1',
                   'experience' => 'INT DEFAULT 0',
                   'power' => 'INT DEFAULT 1',
                   'agility' => 'INT DEFAULT 1', //ловкость
                   'endurance' => 'INT DEFAULT 1', //выносливость
                   'intelligence' => 'INT DEFAULT 1', //интеллект
                   'wisdom' => 'INT DEFAULT 1', //мудрость
                   'volition' => 'INT DEFAULT 1', //воля
                   'health' => 'INT DEFAULT 1',
                   'maxhealth' => 'INT DEFAULT 1',
                   'mana' => 'INT DEFAULT 1',
                   'maxmana' => 'INT DEFAULT 1',
                   'effects' => 'TEXT',
              ),),
          );
          foreach ($c as $k => $v) {
             echo '<h5>Обновление таблицы '.$v['table'].' ...<h5>';
             foreach ($v['columns'] as $k1 => $v1) {
                echo '<h6>Создание столбца `'.$k1.'` ... ';
                $res = addColumn($v['table'], $k1, $v1);
                echo $res === FALSE ? warn() : ($res === 0 ? ok() : err());
                echo '</h6>';
             }
          }
      }
      /********* filling areas and locations ***********/
      if($_POST['fillareas']) {
         mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Лес', 1)");
         mysql_query("REPLACE INTO `areas` (`title`, `id`) VALUES ('Замок', 2)");

         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Погреб', 'Выбраться на кухню=2', 'Большие бочки и запах плесени...', 1, 2, 1)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Кухня', 'Спуститься в погреб=1|Пройти в гостиную=3', 'Разрушенная печь и горшки...', 2, 2, 0)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Гостиная', 'Выбраться на кухню=2|Подняться на чердак=4|Убраться на опушку=6', 'Большой круглый стол, обставленный стульями, картины на стенах...', 3, 2, 0)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Чердак', 'Спуститься в гостиную=3', 'Много старинных вещей и пыли...', 4, 2, 0)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Берлога', 'Двигаться на опушку=6|Выбраться к реке=7', 'Много следов и обглоданные останки...', 5, 1, 0)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Опушка', 'Забраться в берлогу=5|Подняться к реке=7|Войти в замок=3', 'И тут мне надоело...', 6, 1, 0)");
         mysql_query("REPLACE INTO `locations` (`title`, `goto`, `description`, `id`, `super`, `default`) VALUES ('Река', 'Забраться в берлогу=5|Выйти на опушку=6', 'Прозрачная вода и каменистый берег...', 7, 1, 0)");
      }
      /********* filling areas and locations ***********/

      echo '<br /><br /><h3><pre>Ошибок: '.($err?('<span class="err">'.$err.'</span><style>body {background-color: #E6C5C5}</style>'):0)."  Предупреждений: ".($warn?$warn:0)."</pre></h3>";

      }
   else {
      wrongPass();
      fofForm();
   }
}
else fofForm();

echo makePage($HEAD, $BODY);







function wrongPass() {
   global $BODY, $HEAD;
   $HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
   $BODY .= '<span style="color: red">Пароль неверный.</span><br/>';
}


function initResult() {
   global $BODY, $HEAD, $at, $ac, $_POST;
   if (!$at) $at = array(); if (!$ac) $ac = array();
   //$HEAD .= '<meta http-equiv="refresh" content="3;url=init.php">';
   if (array_filter($at) || array_filter($ac) || $_POST['fillareas']) {
      $BODY .= 'Внесённые изменения: <br />';
      if (array_filter($at)) { $cre = ''; foreach (array_filter($at) as $k => $v) $cre .= '  <b>'.$k.'</b><br />'; $BODY .= '<pre>'.' Созданы таблицы:<br />'.$cre.'</pre><br />'; }
      if (array_filter($ac)) { $cre = ''; foreach (array_filter($ac) as $k => $v) $cre .= '  <b>'.$k.'</b><br />'; $BODY .= '<pre>'.' Добавлены столбцы:<br />'.$cre.'</pre><br />'; }
      if ($_POST['fillareas']) $BODY .= '<pre> Тестовые локации заполнены.</pre>';
   }
   else $BODY .= 'Изменений не внесено';
}
//function initError() {
   //
//}

//function initSuccess() {
   //global $BODY, $HEAD;
   //$HEAD .= '<meta http-equiv="refresh" content="3;url=index.php">';
   //$BODY .= 'Успех.';
//}

function fofForm() {
   global $BODY;
   $BODY .=
   '<form method="post" action="init.php">'.
   '<table>'.
   '<thead>Создание базы данных.</thead>'.
   '<tr><td><input type="button" value="Отметить все" onclick="this.chk = this.chk?false:true; this.value=this.chk?\'Снять все\':\'Отметить все\'; ch = function(v) { Array.prototype.forEach.call(document.getElementsByTagName(\'input\'), function(e) { e.checked = v; }); }; if(this.chk) { ch(true); } else { ch(false); }"/></td><td></td>'.
   '<tr><td>Создавать базы:</td><td><input type="checkbox" name="createbases"/></td>'.
   '<tr><td>Создавать таблицы:</td><td><input type="checkbox" name="createtables"/></td>'.
   '<tr><td>Обновлять таблицы:</td><td><input checked type="checkbox" name="updatetables"/></td>'.
   '<tr><td>Заполнить тестовые локации:</td><td><input type="checkbox" name="fillareas"/></td>'.
   '<tr><td>Административный пароль:</td><td><input name="pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'" /></td>'.
   '</table>'.
   '<input type="submit" value="Создать" /><br />';
}

?>