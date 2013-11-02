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
app.use(express.bodyParser());
app.use(express.compress());

app.use('/bootstrap', express.static(__dirname + '/bootstrap'));
app.use('/img', express.static(__dirname + '/img'));
app.use('/browserified', express.static(__dirname + '/browserified'));

var swig = require('swig');
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
				next();
			}
	});
});

/*** routing routines ***/

app.get('/node/', function(request, response) {
	response.send('Node.js is up and running.');
});

/*** real ones ***/

function quickRender(request, response, template)
{
	var options = request.uonline.basicOpts;
	options.instance = template;
	response.render(template, options);
}

app.get('/', function(request, response) {
	response.redirect((request.uonline.basicOpts.loggedIn === true) ?
		config.defaultInstanceForUsers : config.defaultInstanceForGuests);
});

app.get('/about/', function(request, response) {
	quickRender(request, response, 'about');
});

app.get('/register/', function(request, response) {
	quickRender(request, response, 'register');
});

app.post('/register/', phpgate);

app.get('/login/', function(request, response) {
	quickRender(request, response, 'login');
});

app.post('/login/', phpgate);
app.get('/profile/', phpgate);
app.get('/profile/id/:id/', phpgate);
app.get('/profile/user/:user/', phpgate);

app.get('/action/logout', function(request, response) {
	utils.user.closeSession(mysqlConnection, request.cookies.sessid, function(error, result){
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
app.get('/action/go/:to', phpgate);
app.get('/action/attack', phpgate);
app.get('/action/escape', phpgate);

app.get('/ajax/isNickBusy/:nick', function(request, response) {
	utils.user.userExists(mysqlConnection, request.param('nick'), function(error, result){
		if (!!error) { response.send(500); return; }
		response.json({ 'nick': request.param('nick'), 'isNickBusy': result });
	});
});

app.get('/stats/', phpgate);
app.get('/world/', phpgate);
app.get('/development/', phpgate);


app.use(function(err, req, res, next){
	console.error(err.stack);
	res.send(500, 'Something broke!');
});

app.get('*', function(req, res){
	res.send('It\'s a 404', 404);
});


/***** main *****/
var DEFAULT_PORT = 5000;
var port = process.env.PORT || process.env.OPENSHIFT_NODEJS_PORT || DEFAULT_PORT;
var ip = process.env.OPENSHIFT_NODEJS_IP || undefined;
console.log("Starting up on port " + port + ", and IP is " + ip);

if (port != DEFAULT_PORT)
{
	console.log("[grunt] Oh, god, I'm in cloud!");
	console.log("[grunt] Running `grunt ff`.");
	var child = require('child_process').exec('./node_modules/grunt-cli/bin/grunt ff',
		function (error, stdout, stderr) {
			if (stdout.length > 0) console.log('[grunt] stdout: ' + stdout);
			if (stderr.length > 0) console.log('[grunt] stderr: ' + stderr);
			if (error !== null) {
				console.log('[grunt] exec error: ' + error);
			}
			console.log("[grunt] Finished.");
		}
	);
}

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
