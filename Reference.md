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
echo $twig->render('about.twig', array(
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

Options you pass
----------------

* admin (`true` or `false`)
* loggedIn (`true` or `false`)
* login (string or `false`)
* mail_count (number)

### index

None needed.

### register

* error (`true` or `false`)
* invalidLogin (`true` or `false`)
* loginIsBusy (`true` or `false`)
* invalidPass (`true` or `false`)

### login

* error (`true` or `false`)

### game

* location\_name (string)
* area\_name (string)
* pic (URL string)
* description (string)
* ways (array; elements: ways\[i\].to, ways\[i\].name)
* players\_list (array; elements: players\_list\[i\].id, players\_list\[i\].name)
