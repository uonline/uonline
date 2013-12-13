/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


"use strict";

var config = require('./config.js');

var anyDB = require('any-db');
var mysqlConnection = anyDB.createPool(config.MYSQL_DATABASE_URL, {min: 2, max: 20});

var utils = require('./utils.js');

var async = require('async');

var express = require('express');

var app = express();
app.enable('trust proxy');
app.use(express.logger());
app.use(express.cookieParser());
app.use(express.json());
app.use(express.urlencoded());
app.use(express.compress());

app.use('/bootstrap', express.static(__dirname + '/bootstrap'));
app.use('/img', express.static(__dirname + '/img'));
app.use('/browserified', express.static(__dirname + '/browserified'));

var swig = require('swig');
function stubFilter(input) { return input; }
swig.setFilter('tf', stubFilter); // TODO: actually implement
swig.setFilter('nl2p', stubFilter); // TODO: actually implement
swig.setFilter('nl2br', stubFilter); // TODO: actually implement
swig.setFilter('length', function(){ return 0; }); // TODO: actually implement
app.engine('html', swig.renderFile);
app.engine('twig', swig.renderFile);
app.engine('swig', swig.renderFile);
app.set('view engine', 'twig'); // historical reasons
app.set('views', __dirname + '/templates');

var phpgate = require('./cgi.js').phpgate;

app.use(function (request, response, next) {
	response.header('Content-Security-Policy-Report-Only',
		"default-src 'self'; script-src 'self' http://code.jquery.com"
	);
	next();
});

app.use(function (request, response, next) {
	request.uonline = {};
	request.uonline.basicOpts = {};
	utils.user.sessionInfoRefreshing(
		mysqlConnection, request.cookies.sessid, config.sessionExpireTime, function(error, result){
			if (!!error)
			{
				response.send(500);
			}
			else
			{
				request.uonline.basicOpts.now = new Date();
				request.uonline.basicOpts.loggedIn = result.sessionIsActive;
				request.uonline.basicOpts.login = result.username;
				request.uonline.basicOpts.admin = result.admin;
				request.uonline.basicOpts.userid = result.userid;
				next();
			}
	});
});

/*** routing routines ***/

app.get('/node/', function (request, response) {
	response.send('Node.js is up and running.');
});

app.get('/explode/', function (request, response) {
	throw new Error('Emulated error.');
});

/*** real ones ***/

function quickRender(request, response, template)
{
	var options = request.uonline.basicOpts;
	options.instance = template;
	response.render(template, options);
}

function quickRenderError(request, response, code)
{
	var options = request.uonline.basicOpts;
	options.code = code;
	options.instance = 'error';
	response.status(code);
	response.render('error', options);
}

app.get('/', function (request, response) {
	response.redirect((request.uonline.basicOpts.loggedIn === true) ?
		config.defaultInstanceForUsers : config.defaultInstanceForGuests);
});

app.get('/about/', function (request, response) {
	quickRender(request, response, 'about');
});

app.get('/register/', function (request, response) {
	quickRender(request, response, 'register');
});

app.post('/register/', function (request, response) {
	var options = request.uonline.basicOpts;
	options.instance = 'register';
	async.auto({
			usernameIsValid: function (callback, results) {
				callback(null, utils.validation.usernameIsValid(request.body.user));
			},
			passwordIsValid: function (callback, results) {
				callback(null, utils.validation.passwordIsValid(request.body.pass));
			},
			userExists: ['usernameIsValid', function (callback, results) {
				utils.user.userExists(mysqlConnection, request.body.user, callback);
			}],
			register: ['usernameIsValid', 'passwordIsValid', 'userExists', function (callback, results) {
				if (results.usernameIsValid === true && results.passwordIsValid === true &&
					results.userExists === false)
				{
					utils.user.registerUser(mysqlConnection, request.body.user, request.body.pass,
						config.PERMISSIONS_USER, callback);
				}
				else
				{
					callback(null, 'validation fail');
				}
			}],
		},
		function (error, results) {
			if (!!error || results.register === 'validation fail')
			{
				options.error = true; // TODO: report mysql errors explicitly
				// TODO: simplify template params
				options.invalidLogin = !results.usernameIsValid;
				options.invalidPass = !results.passwordIsValid;
				options.loginIsBusy = results.userExists;
				options.user = request.body.user;
				options.pass = request.body.pass;
				response.render('register', options);
			}
			else
			{
				// TODO: set sessid
				//response.redirect(config.defaultInstanceForUsers);
				response.redirect('/login/');
			}
		}
	);
});

app.get('/login/', function (request, response) {
	quickRender(request, response, 'login');
});

app.post('/login/', function (request, response) {
	var options = request.uonline.basicOpts;
	options.instance = 'login';
	async.auto(
		{
			'accessGranted': function (callback) {
				utils.user.accessGranted(mysqlConnection, request.body.user, request.body.pass, callback);
			},
			'setSession': ['accessGranted', function (callback, results) {
				if (results.accessGranted === true)
				{
					utils.user.setSession(mysqlConnection, request.body.user, callback);
				}
				else
				{
					callback('access denied', null);
				}
			}],
			'cookie': ['setSession', function (callback, results) {
				response.cookie('sessid', results.setSession);
				callback(null, null);
			}],
		},
		function (error, results) {
			if (!error)
			{
				response.redirect('/');
			}
			else
			{
				// TODO: report mysql errors explicitly
				options.error = true;
				options.user = request.body.user;
				response.render('login', options);
			}
		}
	);
});

app.get('/profile/', phpgate);
app.get('/profile/id/:id/', phpgate);
app.get('/profile/user/:user/', phpgate);

app.get('/action/logout', function (request, response) {
	utils.user.closeSession(mysqlConnection, request.cookies.sessid, function (error, result) {
		if (!!error)
		{
			response.send(500);
		}
		else
		{
			response.redirect('/');
		}
	}); // TODO: move sessid to uonline{}
});

app.get('/game/', phpgate);
app.get('/node-game/', function (request, response) {
	if (!request.uonline.basicOpts.loggedIn)
	{
		response.redirect('/login/');
	}
	else
	{
		var options = request.uonline.basicOpts;
		options.instance = 'game';
		utils.game.getUserLocation(mysqlConnection, request.uonline.basicOpts.userid, function (error, result) {
			if (!!error)
			{
				throw new Error(error);
			}
			options['location_name'] = result.title;
			options['area_name'] = 'FIXME! FIXME! FIXME!'; // TODO: FIXME
			if (!!options.picture) options['pic'] = options.picture;
			options['description'] = result.description;
			options['ways'] = result['goto'];
			options['ways'].forEach(function (i) { // facepalm
				i.name = i.text;
				i.to = i.id;
			});
			options['players_list'] = []; // TODO: broken
			options['monsters_list'] = []; // TODO: broken
			options['fight_mode'] = false; // TODO: broken
			options['autoinvolved_fm'] = false; // TODO: broken
			response.render('game', options);
		});
	}
});

app.get('/action/go/:to', function (request, response) {
	utils.game.changeLocation(
		mysqlConnection,
		request.uonline.basicOpts.userid,
		request.param('to'),
		function (error, result) {
			if (!!error)
			{
				throw new Error(error);
			}
			response.redirect('/game/');
		}
	);
});

app.get('/action/attack', function (request, response) {
	if (!request.uonline.basicOpts.loggedIn)
	{
		response.redirect('/login/');
	}
	else
	{
		utils.game.goAttack(mysqlConnection, request.uonline.basicOpts.userid, function (error, result) {
			if (!!error)
			{
				throw new Error(error);
			}
			else
			{
				response.redirect('/game/');
			}
		});
	}
});

app.get('/action/escape', function (request, response) {
	if (!request.uonline.basicOpts.loggedIn)
	{
		response.redirect('/login/');
	}
	else
	{
		utils.game.goEscape(mysqlConnection, request.uonline.basicOpts.userid, function (error, result) {
			if (!!error)
			{
				throw new Error(error);
			}
			else
			{
				response.redirect('/game/');
			}
		});
	}
});

app.get('/ajax/isNickBusy/:nick', function (request, response) {
	utils.user.userExists(mysqlConnection, request.param('nick'), function(error, result){
		if (!!error) { response.send(500); return; }
		response.json({ 'nick': request.param('nick'), 'isNickBusy': result });
	});
});

//app.get('/stats/', phpgate);
//app.get('/world/', phpgate);
//app.get('/development/', phpgate);

// 404 handling
app.get('*', function (request, response) {
	quickRenderError(request, response, 404);
});

// Exception handling
app.use(function (error, request, response, next) {
	console.error(error.stack);
	quickRenderError(request, response, 500);
});


/***** main *****/
var DEFAULT_PORT = 5000;
var port = process.env.PORT || process.env.OPENSHIFT_NODEJS_PORT || DEFAULT_PORT;
var ip = process.env.OPENSHIFT_NODEJS_IP || undefined;
console.log("Starting up on port " + port + ", and IP is " + ip);

var startupFinished = function() {
	console.log("Listening on port " + port);
	if (port == DEFAULT_PORT) console.log("Try http://localhost:" + port + "/");
};

if (ip !== undefined)
{
	app.listen(port, ip, startupFinished);
}
else
{
	app.listen(port, startupFinished);
}
