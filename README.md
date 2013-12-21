uonline [![Build Status](https://travis-ci.org/uonline/uonline.png?branch=master)](https://travis-ci.org/uonline/uonline) [![Coverage Status](https://coveralls.io/repos/uonline/uonline/badge.png?branch=master)](https://coveralls.io/r/uonline/uonline?branch=master) [![Dependency Status](https://david-dm.org/uonline/uonline.png)](https://david-dm.org/uonline/uonline) [![devDependency Status](https://david-dm.org/uonline/uonline/dev-status.png)](https://david-dm.org/uonline/uonline#info=devDependencies) 
=======

A browser-based MMORPG game in a fantasy world.


Requirements
------------

### Current

* Node.js with npm
* CoffeeScript
* Grunt
* MySQL or MariaDB
* MySQL user `anonymous` with password `nopassword`

### Legacy

* PHP 5.4 or higher
* PHP-MySQL module
* PHP-CGI package

### Future

* PostgreSQL


How to set up
-------------

* Clone the repo.
* Install packages: `npm install`, `./composer.phar install`.
* Create keyring (for PHP). You can run almost any PHP file to get help on format.
* Fetch submodules: `git submodule init`, `git submodule update`.
* Initialize database: `./init.php --database --tables --unify-validate --unify-export --test-monsters --optimize`.
* If you need to add an admin: `./add-admin.coffee username password`.


How to run
----------

If you have Heroku Toolbelt, run `foreman start` to get the server running. If not, try `./main.coffee`.

If you wanna run legacy PHP version - you know the way.


Tips and tricks for PHP version
-------------------------------

* MySQL package in Debian is called `mysql-server`. Don't forget to run `mysql_secure_installation`.
* Apache package in Debian is called `apache2`. Configure virtual hosts if you need it.
* PHP package in Debian is called `php5`. Warning: it's pretty outdated. To fetch the latest:

```
sudo add-apt-repository ppa:ondrej/php5
sudo apt-get update
sudo apt-get install php5
```

* 404 at main page? `.htaccess` problem. Enable `mod_rewrite`, edit your apache config and tell it the magic phrase `AllowOverride All`.
* In case of database problems, make sure that `mysql` and `mysqli` extensions are enabled in php.ini. In Debian, you will also need a package named `php5-mysql`.
* It is designed to run with xcache/opcache and native Twig extension. But they're both optional. Just in case: package `php5-xcache` in Debian for xcache, package `php5-dev` to build ext. `vendor/twig/twig/ext/twig`. [How to build](http://twig.sensiolabs.org/doc/intro.html#installing-the-c-extension).
* Turn caching on in keyring. It helps a lot, too.
* And the last. If you want to see code coverage reports, install xdebug (package `php5-xdebug` in Debian).

If you experience problems, try to run `make diagnose` to diagnose the most common problems.

To correctly update uonline on production server, try `make deploy`. To update Composer, run `php composer.phar selfupdate`. To update third-party libraries, run `php composer.phar update`.

To run PHP tests, run `make test`. Note that they cover not all the code.


Programmers' guidelines
-----------------------

**Hint:** Run `grunt` to check and test your code.

* Use tabs, not spaces. Don't mix them and don't use smarttabs.
* Prefer single quotes. Use double quotes when you need to escape `'` itself.
* Place `use strict` in every file.
* Don't omit extension while requiring: `require('./utils.js');`.
* Sync is better than async. Async is better than callbacks.
* Write tests for everything.
* Write good assert comments: they should answer the question "What do this function should do?".
* Keep things outside of main thread. Use asynchronous API.


### JS-specific

* Use `if (!!something)` when checking for null or undefined.
* Use semicolons even if they're optional.
* Place figure brackets on the same line when you declare an anonymous function and on separate line otherwise.

```js
exports.closeSession = function(dbConnection, sess, callback) {
	if (!sess)
	{
		callback(undefined, 'Not closing: empty sessid');
	}
	else
	{
		dbConnection.query(
			'UPDATE `uniusers` SET `sessexpire` = NOW() - INTERVAL 1 SECOND WHERE `sessid` = ?',
			[sess], callback);
	}
};
```

* Use trailing commas. Place them even after last element - it allows you to swap lines easily.

```js
var numbers = [
  1,
  2,
  3,
  4,
];
```


### CoffeeScript-specific

* Use `?` when checking for null or undefined: `if error? then ...`.
* Leave two empty lines between function definitions.
* `() ->` and `->` are both acceptable, `->` is preferred.
* Use interpolation instead of concatenation.
* Use `unless` instead of `if not`. Don't use `unless ... else` at all.
* Use `is` instead of `==` when you don't mean calculations.
* Overall: don't try to make CS look like JS.
