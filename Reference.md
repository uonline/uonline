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
* isInBattle (`true` or `false`)
* autoStartedBattle (`true` or `false`)

### profile

* nickname (string)
* id (string)
* level, exp, exp_max, exp\_percent (string)
* power, agility, endurance (string)
* intelligence, wisdom, volition (string)
* health, health\_max, health\_percent (string)
* mana, mana\_max, mana\_percent (string)
* effects (array; elements: effects\[i\].name, effects\[i\].description, effects\[i\].dismiss_time)
