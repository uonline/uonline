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

var express = require('express');
var twig = require('twig');
//var utils = require('./utils.js');

var app = express();
app.use(express.logger());

app.use('/bootstrap', express.static(__dirname + '/bootstrap'));
app.use('/img', express.static(__dirname + '/img'));

//utils.dbConnect();

app.get('/node/', function(request, response) {
	response.send('Node.js is up and running.');
});

function phpgate(request, response)
{
	var child_process = require('child_process');
	child_process.execFile('php', ['index.php', 'nodecall', request.originalUrl], {}, function (error, stdout, stderr) {
		console.log('PHP stdout: ' + stdout);
		console.log('PHP stderr: ' + stderr);
		if (error !== null) {
			console.log('PHP exec error: ' + error);
			response.send('PHP gate error. See console for details.');
		}
		response.send(stdout);
	});
}

app.get('/', phpgate);
app.get('/about/', phpgate);
app.get('/register/', phpgate);
app.post('/register/', phpgate);
app.get('/login/', phpgate);
app.post('/login/', phpgate);
app.post('/profile/', phpgate);
//app.post('/profile/id/{id}/', phpgate);
//app.post('/profile/user/{user}/', phpgate);
app.get('/action/logout', phpgate);
app.get('/game/', phpgate);
//app.get('/action/go/{to}', phpgate);
app.get('/action/attack', phpgate);
app.get('/action/escape', phpgate);
//app.get('/ajax/isNickBusy/{nick}', phpgate);
app.get('/stats/', phpgate);
app.get('/world/', phpgate);
app.get('/development/', phpgate);


/*
app.get('/', function(request, response) {
	response.redirect('/about/');
});

app.get('/about/', function(request, response) {
	var t = Date.now();
	var options = {};
	options.instance = 'about';
	options.loggedIn = false;
	response.render('about.twig', options);
	console.log(request.path+' - done in '+(Date.now()-t)+' ms');
});
*/

/***** main *****/
var port = process.env.PORT || 5000;
app.listen(port, function() {
	console.log("Listening on " + port);
	if (port==5000) console.log("Try http://localhost:" + port + "/");
});
