<?php

require_once('utils.php');

$HEAD = $BODY = '';

if ($_POST) {
   if ($_POST['pass'] == ADMIN_PASS) {

      mysqlInit();

      if ($_POST['createbases'])
      $at = createTables();

      if ($_POST['updatebases'])
      $ac = updateColumns();

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

      initResult();
   }
   else {
      wrongPass();
      fofForm();
   }
}
else fofForm();

insertEncoding('utf-8');
echo makePage($HEAD, $BODY, 'utf-8');







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
   'Создание базы данных.<br/><br/>'.
   'Создавать базы: <input type="checkbox" name="createbases"/><br/>'.
   'Обновлять базы: <input checked type="checkbox" name="updatebases"/><br/>'.
   'Заполнить таблицы тестовыми локациями: <input type="checkbox" name="fillareas"/><br/>'.
   'Административный пароль: <input name="pass" type="password" value="'.(ADMIN_PASS=='clearpass'?ADMIN_PASS:'').'" /><br/><br/>'.
   '<input type="submit" value="Создать" /><br/>';
}

?>