uonline
=======

A browser-based MMORPG game in a fantasy world.


Deployment
----------

1. Clone the repo.
2. Install MySQL (package `mysql-server` in Debian). Run `mysql_secure_installation`.
3. Install Apache (package `apache2` in Debian). Configure virtual hosts if you need it. Now navigate to your project URL and you must see a lot of lines of source code. Web server is working, great.
4. Install PHP (package `php5` in Debian). Navigate to your project URL and now you must see blank page. This means PHP is working. You see the warning about missing keyring? Create it.
5. Okay, it won't run without required libraries. Run `php composer.phar install` to install them.
6. Install [htmlcompressor](http://code.google.com/p/htmlcompressor/). In Arch Linux, there is a package in AUR.
7. Install Java (package `openjdk-7-jre-headless` in Debian).
8. Let's prepare our templates. Run `./compress-templates.sh`. It tries to run `/bin/java`? Congratulations, your `JAVA_HOME` is not set. Edit your `/usr/bin/htmlcompressor` and tell it to just run `/usr/bin/java`.
9. Something is still wrong? 404? `.htaccess` problem. Enable `mod_rewrite`, edit your apache config and tell it the magic phrase `AllowOverride All`.
10. Now it must be up and running. One more thing! Navigate to `http://your_project_url/init.php` and create some tables. It cannot connect to database? Make sure `mysql` and `mysqli` extensions are enabled. In Debian, you will need a package named `php5-mysql`.
11. Tables are created and filled with some test data. Gooooood. Well, now you probably want to fill it with real data. `git submodule update --init`, `php locparse.php --validate unify`, `php locparse.php --export unify`.
12. Add an admin. Navigate to `http://your_project_url/add-admin.php` and do the thing.
13. OH, A NASTY BUG! Default location is not set. We will fix it, honestly. But for now... Run mysql client and say `update uniusers set location=2147483647` in your database.
14. And the last. To make it even faster, install the Twig extension. In Debian, you will need package `php5-dev`. Install it, chdir to `vendor/twig/twig/ext/twig` and [build, install and activate](http://twig.sensiolabs.org/doc/intro.html#installing-the-c-extension) the extension. Turn caching on in keyring. Here we go.
