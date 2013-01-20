Common actions
--------------

```php
<?php

$time_start = microtime(true);

require_once './Twig/Autoloader.php';
Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array(
   //'cache' => './templates_cache', // UNCOMMENT LATER
   'cache' => false,
));


///////////////////////////
///// DO SOME WORK... /////
///////////////////////////


// and render template you need
echo $twig->render('index.twig', array(
   'admin' => false,
   'loggedIn' => sessionActive($s),
   'login' => userBySession($s),
   'mail_count' => 0,
   // other options...
));

$time_end = microtime(true);
echo "\n<!-- Done in ".( ($time_end - $time_start) *1000).' milliseconds -->';

?>
```
