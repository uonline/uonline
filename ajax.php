<?php

require_once 'utils.php';

$args = $_GET;

if($args['isNickBusy']) {
   echo ajaxAnswere( array('nick' => $args['isNickBusy'],'isNickBusy' => userExists($args['isNickBusy'])) );
}

function ajaxAnswere($a) {
   $o = '';
   foreach ($a as $k => $v) $o .= '"'.$k.'": '.(is_bool($v)?($v?'true':'false'):'"'.$v.'"').', ';
   $o = '{ '.preg_replace('/\\,\\s+$/', '', $o).' }';
   return $o;
}



?>