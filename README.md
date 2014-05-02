uonline
=======

[![Build Status](https://travis-ci.org/uonline/uonline.svg?branch=master)](https://travis-ci.org/uonline/uonline)
[![Coverage Status](https://coveralls.io/repos/uonline/uonline/badge.png?branch=master)](https://coveralls.io/r/uonline/uonline?branch=master)
[![Dependency Status](https://david-dm.org/uonline/uonline.svg)](https://david-dm.org/uonline/uonline)
[![devDependency Status](https://david-dm.org/uonline/uonline/dev-status.svg)](https://david-dm.org/uonline/uonline#info=devDependencies)
[![Code Climate](https://codeclimate.com/github/uonline/uonline.png)](https://codeclimate.com/github/uonline/uonline)
[![Tasks for this week](https://badge.waffle.io/uonline/uonline.png?label=this%20week&title=Tasks)](http://waffle.io/uonline/uonline)

A browser-based MMORPG game in a fantasy world.


Requirements
------------

* Node.js 0.10 with npm;
* CoffeeScript;
* Grunt (you may use local one, but why?);
* PostgreSQL 9.1 or higher;
* DB user `anonymous` with password `nopassword`;
* Two databases: `uonline` and `uonline_test`.


How to set up
-------------

* Clone the repo.
* Install packages: `npm install`
* Fetch submodules: `git submodule init`, `git submodule update`
* Initialize database: `./init.coffee --migrate-tables --unify-export --test-monsters --optimize-tables`
* If you need to add an admin: `./add-admin.coffee username password`


How to run
----------

If you have Heroku Toolbelt, run `foreman start` to get the server running. If not, try `./main.coffee`. If you need to restart server after every change in code - `make monitor`.


Programmers' guidelines
-----------------------

**Hint:** Run `grunt` to check and test your code. Run something like `grunt test --single health-check.coffee` to run a single testsuite.

* Use tabs, not spaces. Don't mix them and don't use smarttabs.
* Prefer single quotes. Use double quotes when you need to escape `'` itself.
* Place `use strict` in every file.
* Don't omit extension while requiring: `require('./utils.js');`.
* Sync is better than async. Async is better than callbacks.
* Write tests for everything.
* Write good assert comments: they should answer the question "What do this function should do?".
* Keep things outside of main thread. Use asynchronous API.


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

* Use trailing commas. Place them even after last element - it allows you to swap lines easily.

```js
var numbers = [
  1,
  2,
  3,
  4,
];
```
