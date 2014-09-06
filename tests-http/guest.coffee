#!/usr/bin/env coffee

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


'use strict'

unit = require 'unit.js'
config = require "#{__dirname}/../config.js"
site = unit.httpAgent "http://localhost:#{config.defaultPort}"


finish = (test) ->
	(error, result) ->
		if error?
			test.ok false, error.message
		else
			test.ok true, 'all done'
		test.done()


exports['/'] = (test) ->
	site
		.get '/'
		.expect 302  # redirect
		.expect (response) ->
			test.strictEqual response.header.location, '/about/', 'should redirect to /about/'
		.end(finish(test))


exports['/404/'] = (test) ->
	site
		.get '/404/'
		.expect 404
		.expect /[&]copy[;] m1kc и К[<]sup[>]о[<][/]sup[>]/  # custom template rendered
		.expect /404/  # page rendered
		.expect /Страница не найдена/  # page rendered
		.end(finish(test))


exports['/explode/'] = (test) ->
	site
		.get '/explode/'
		.expect 500
		.expect /[&]copy[;] m1kc и К[<]sup[>]о[<][/]sup[>]/  # custom template rendered
		.expect /500/  # page rendered
		.expect /Внутренняя ошибка сервера/  # page rendered
		.end(finish(test))


exports['/node/'] = (test) ->
	site
		.get '/node/'
		.expect 200
		.expect /Node.js is up and running/  # page rendered
		.end(finish(test))


exports['/about/'] = (test) ->
	site
		.get '/about/'
		.expect 200
		.expect /[&]copy[;] m1kc и К[<]sup[>]о[<][/]sup[>]/  # custom template rendered
		.expect /Первая в мире текстовая браузерная MMORPG/  # page rendered
		.end(finish(test))


exports['/login/'] = (test) ->
	site
		.get '/login/'
		.expect 200
		.expect /[&]copy[;] m1kc и К[<]sup[>]о[<][/]sup[>]/  # custom template rendered
		.expect /Вход/  # page rendered
		.expect /Логин/  # page rendered
		.expect /Пароль/  # page rendered
		.expect /Войти/  # page rendered
		.end(finish(test))


exports['/register/'] = (test) ->
	site
		.get '/register/'
		.expect 200
		.expect /[&]copy[;] m1kc и К[<]sup[>]о[<][/]sup[>]/  # custom template rendered
		.expect /Регистрация/  # page rendered
		.expect /Логин/  # page rendered
		.expect /Пароль/  # page rendered
		.expect /Зарегистрироваться/  # page rendered
		.end(finish(test))
