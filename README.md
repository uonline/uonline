uonline [![Build Status](https://travis-ci.org/uonline/uonline.png?branch=master)](https://travis-ci.org/uonline/uonline)
=======

A browser-based MMORPG game in a fantasy world.


Requirements
------------

* Node.js with npm;
* PHP 5.4 or higher;
* PHP-MySQL module;
* PHP-CGI package;
* MySQL or MariaDB;
* MySQL user `anonymous` with password `nopassword`;
* PostgreSQL (currently not used).


Common problems
---------------

* Don't forget to install packages (`npm install` and `./composer.phar install`).
* Don't forget to create keyring.
* Don't forget to get submodules (`git submodule init`, `git submodule update`);
* Don't forget to initialize database (`./init.php --database --tables --unify-validate --unify-export --test-monsters --optimize`).
* If nothing helps, ask [m1kc](https://github.com/m1kc).


Deployment (Node.js)
--------------------

1. Clone the repo.
2. Install Node.js.
3. Run `npm install`.
4. Install and set up MySQL (see below).
5. Install and set up PostgreSQL.
6. If you have Heroku Toolbelt, run `foreman start` to get the server running. If not, try `node main.js`.


Deployment (PHP)
----------------

1. Clone the repo.
2. Install MySQL (package `mysql-server` in Debian). Run `mysql_secure_installation`.
3. Install Apache (package `apache2` in Debian). Configure virtual hosts if you need it. Now navigate to your project URL and you must see a lot of lines of source code. Web server is working, great.
4. Install PHP (package `php5` in Debian). Navigate to your project URL and now you must see blank page. This means PHP is working. You see the warning about missing keyring? Create it.
5. Okay, it won't run without required libraries. Run `php composer.phar install` to install them.
6. Install [htmlcompressor](http://code.google.com/p/htmlcompressor/). In Arch Linux, there is a package in AUR.
7. Install Java (package `openjdk-7-jre-headless` in Debian).
8. Let's prepare our templates. Run `./compress-templates.sh`. It tries to run `/bin/java`? Congratulations, your `JAVA_HOME` is not set. Edit your `/usr/bin/htmlcompressor` and tell it to just run `/usr/bin/java`.
9. Something is still wrong? 404? `.htaccess` problem. Enable `mod_rewrite`, edit your apache config and tell it the magic phrase `AllowOverride All`.
10. Now it must be up and running. Run `php init.php` with the keys you need. It cannot connect to database? Make sure `mysql` and `mysqli` extensions are enabled. In Debian, you will need a package named `php5-mysql`.
12. Add an admin. Run `php add-admin.php`.
13. To make it even faster, install xcache (package `php5-xcache` in Debian) or turn opcache on (if you have PHP 5.5).
13. To make it _even_ faster, install the Twig extension. In Debian, you will need package `php5-dev`. Install it, chdir to `vendor/twig/twig/ext/twig` and [build, install and activate](http://twig.sensiolabs.org/doc/intro.html#installing-the-c-extension) the extension. Turn caching on in keyring. Here we go.
14. And the last. If you want to see code coverage reports, install xdebug (package `php5-xdebug` in Debian).

If you experience problems, try to run `make diagnose` to diagnose the most common problems.

To correctly update uonline, run `make deploy`. To update Composer, run `php composer.phar selfupdate`. To update third-party libraries, run `php composer.phar update`.

To run tests, run `make test`. Note that they cover not all the code.
