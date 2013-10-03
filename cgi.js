/*
 *
 * (The MIT License)
 *
 * Copyright (c) 2012 Nathan Rajlich nathan@tootallnate.net
 * Copyright (c) 2013 m1kc m1kc@yandex.ru
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files
 * (the 'Software'), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall
 * be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
 * AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */


function extend(source, destination) {
	for (var i in source) {
		destination[i] = source[i];
	}
	return destination;
}

function phpgate(request, response)
{
	var child_process = require('child_process');
	var querystring = require('querystring');

	var env = {};
	extend(process.env, env);
	extend({
		'GATEWAY_INTERFACE': 'CGI/1.1',
		//SCRIPT_NAME: options.mountPoint,
		'SCRIPT_FILENAME': 'index.php',
		'REDIRECT_STATUS': 200,
		//PATH_INFO: req.uri.pathname.substring(options.mountPoint.length),
		'REQUEST_URI': request.originalUrl,
		//SERVER_NAME: address || 'unknown',
		//SERVER_PORT: port || 80,
		//SERVER_PROTOCOL: SERVER_PROTOCOL,
		//SERVER_SOFTWARE: SERVER_SOFTWARE
	}, env);
	for (var header in request.headers) {
		var name = 'HTTP_' + header.toUpperCase().replace(/-/g, '_');
		env[name] = request.headers[header];
	}
	//extend(options.env, env);
	env.REQUEST_METHOD = request.method;
	//env.QUERY_STRING = request.uri.query || '';
	if ('content-length' in request.headers) {
		env.CONTENT_LENGTH = request.headers['content-length'];
	}
	if ('content-type' in request.headers) {
		env.CONTENT_TYPE = request.headers['content-type'];
	}
	if ('authorization' in request.headers) {
		var auth = request.headers.authorization.split(' ');
		env.AUTH_TYPE = auth[0];
	}
	// SPAWN!
	var cgiSpawn = child_process.spawn('php-cgi', [], { env: env });
	// Re-send POST data
	cgiSpawn.stdin.write(querystring.stringify(request.body));

	var CGIParser = require('./cgiparser.js');
	var cgiResult = new CGIParser(cgiSpawn.stdout);
	// When the blank line after the headers has been parsed, then
	// the 'headers' event is emitted with a Headers instance.
	cgiResult.on('headers', function(headers) {
		headers.forEach(function(header) {
			// Don't set the 'Status' header. It's special, and should be
			// used to set the HTTP response code below.
			if (header.key === 'Status') return;
			response.header(header.key, header.value);
		});

		// set the response status code
		response.statusCode = parseInt(headers.status, 10) || 200;
	});

	cgiResult.on('leftover', function (chunk) {
		response.send(chunk);
	});

	cgiResult.on('error', function (something) {
		console.log('PHP gate error');
		console.log(something);
	});
}

/*** exports ***/
exports.phpgate = phpgate;
