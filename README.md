uonline
=======

[![Build Status](https://travis-ci.org/uonline/uonline.svg?branch=master)](https://travis-ci.org/uonline/uonline)
[![Coverage Status](https://img.shields.io/coveralls/uonline/uonline.svg)](https://coveralls.io/r/uonline/uonline?branch=master)
[![Dependency Status](https://img.shields.io/david/uonline/uonline.svg)](https://david-dm.org/uonline/uonline)
[![devDependency Status](https://img.shields.io/david/dev/uonline/uonline.svg)](https://david-dm.org/uonline/uonline#info=devDependencies)
[![Planned tasks](https://badge.waffle.io/uonline/uonline.svg?label=on%20fire&title=Tasks)](http://waffle.io/uonline/uonline)

A browser-based MMORPG in a fantasy world.


Requirements
------------

* Node.js 0.10 or higher with npm;
* CoffeeScript;
* Gulp;
* Bower;
* PostgreSQL 9.1 or higher.

uonline expects environment variables `DATABASE_URL` and `DATABASE_URL_TEST` to be set. If they are not, it will use following default credentials. You'll probably find it convinient to make the dev environment match them.

* Hostname `localhost`;
* DB user `anonymous` with password `nopassword`;
* Databases: `uonline` and `uonline_test`.


How to set up
-------------

* Clone the repo.
* Run `script/setup`. Please note that it expects database credentials to be set. Also, it will try to create databases if they don't exist.

By the way, running `script/update` will update the stuff like dependencies and DB revisions. You typically use it after every pull.


How to run
----------

Run `script/run`.

There are also some alternatives:
* `foreman start` if you want to simulate Heroku environment.
* `./main.coffee` for plain run.
* `make monitor` to automatically restart server on changes.

The following environment variables are recognized:

* `IP`, `PORT` — IP and port to listen;
* `DATABASE_URL`, `DATABASE_URL_TEST` — database credentials;
* `SQLPROF`=`true` — show SQL timings in console (doesn't work with transactions);
* `NOCSP` — don't output CSP header;
* `NEW_RELIC_LICENSE_KEY` — you don't need this.


Gulp hints
----------

Run `gulp` to check and test your code. It will lint your code, run tests, show coverage stats and so on. Please run it before every commit.

Useful subtasks:

* `gulp check` — only lint;
* `gulp build` — build static assets;
* `gulp watch` — same as `gulp build`, but works automagically.
* `gulp test` — run unittests without additional checks.

Useful options:

* `gulp test --single health-check.coffee` — run only one testsuite;
* `gulp test --reporter verbose` — use other reporter.

Using Grunt is deprecated.


Programmers' guidelines
-----------------------

* Use tabs, not spaces. Don't mix them and don't use smarttabs.
* Prefer single quotes. Use double quotes when you need to escape `'` itself.
* Place `use strict` in every file.
* Don't omit extension while requiring: `require('./utils.js');`.
* Sync is better than async. Async is better than callbacks.
* Write tests for everything.
* Write good assert comments: they should answer the question "What do this function should do?".
* Keep things outside of main thread: use asynchronous API. And remember: `fs.readFile.sync()` is way better than `fs.readFileSync()`.


### CoffeeScript-specific

* Use `?` when checking for null or undefined: `if error? then ...`.
* Leave two empty lines between function definitions.
* `->` is preferred, `() ->` is acceptable.
* Use interpolation instead of concatenation.
* Use `unless` instead of `if not`. Don't use `unless ... else` at all.
* Use `is` instead of `==` when you don't mean calculations.
* Overall: don't try to make CS look like JS.


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
			'UPDATE `uniusers` SET `sessexpire` = NOW() WHERE `sessid` = ?',
			[sess], callback);
	}
};
```

* Use trailing commas. Place them even after last element — it allows you to swap lines easily.

```js
var numbers = [
  1,
  2,
  3,
  4,
];
```
