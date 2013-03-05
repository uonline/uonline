<?php

require_once 'utils.php';

$args = $_GET;

if($args['isNickBusy']) {
   echo ajaxAnswere( array('nick' => $args['isNickBusy'],'isNickBusy' =>(userExists($args['isNickBusy'])?'true':'false')) );
}

function ajaxAnswere($a) {
   $o = '';
   foreach ($a as $k => $v) $o .= $k.': '.$v.', ';
   $o = '{ '.preg_replace('/\\,\\s+$/', '', $o).' }';
   return $o;
}



?>