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

NS = 'validation'; exports[NS] = {}  # namespace
{test, requireCovered, config} = require '../lib/test-utils.coffee'

validation = requireCovered __dirname, '../lib/validation.coffee'


exports[NS].usernameIsValid = ->
	test.strictEqual validation.usernameIsValid('m1kc'), true, 'should pass good names'
	test.strictEqual validation.usernameIsValid('Волшебник'), true, 'should pass good names'
	test.strictEqual validation.usernameIsValid('Михаил Кутузов'), true, 'should pass good names'
	test.strictEqual validation.usernameIsValid('Чёрный Властелин'), true, 'should pass good names'
	test.strictEqual validation.usernameIsValid('b'), false, 'not too short'
	test.strictEqual validation.usernameIsValid('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), false, 'not too long'
	test.strictEqual validation.usernameIsValid('DROP TABLE `users`;'), false, 'no odd characters'
	test.strictEqual validation.usernameIsValid(undefined), false, "missing name can't be valid"
	test.strictEqual validation.usernameIsValid(null), false, "missing name can't be valid"
	test.strictEqual validation.usernameIsValid('you_shall_not_pass_maybe'), true, 'should pass underscores'
	test.strictEqual validation.usernameIsValid('   '), false, 'should not pass shit'
	test.strictEqual validation.usernameIsValid('---'), false, 'should not pass shit'
	test.strictEqual validation.usernameIsValid(' Max '), false, 'should not pass shit'
	test.strictEqual validation.usernameIsValid('-Max-'), false, 'should not pass shit'


exports[NS].emailIsValid = ->
	test.strictEqual validation.emailIsValid('security@mail.ru'), true, 'should pass good emails'
	test.strictEqual validation.emailIsValid('wtf'), false, 'should not pass the shit'
	test.strictEqual validation.emailIsValid(undefined), false, 'empty mail - invalid mail'
	test.strictEqual validation.emailIsValid(null), false, 'empty mail - invalid mail'


exports[NS].passwordIsValid = ->
	test.strictEqual validation.passwordIsValid('make install clean'), true, 'should pass good passwords'
	test.strictEqual validation.passwordIsValid('вобла'), false, 'should not pass Russian'
	test.strictEqual validation.passwordIsValid('b'), false, 'not too short'
	test.strictEqual validation.passwordIsValid('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), false, 'not too long'
	test.strictEqual validation.passwordIsValid(undefined), false, 'not passed - not valid'
	test.strictEqual validation.passwordIsValid(null), false, 'not passed - not valid'


exports[NS].characterNameIsValid = ->
	for [name, result, message] in [
		['Sashok',         true,  'good name is ok']
		['Нагибатор',      true,  'good name in russion is ok too']
		['rm-rf',          true,  'dashes are allowed']
		['ДитЯ СолныФкА',  true,  'spaces are allowed']
		['InfernaL_DeviL', false, 'no underscores']
		['Qwerty Йцукен',  false, 'no latin and russian mix']
		['rm -rf',         false, 'no multiple spaces/dashes in a row']
		['R2D2',           false, 'no digits']
		[' spaaace',       false, 'no front spaces']
		['spaaace ',       false, 'no trailing spaces']
		['-Infinity',      false, 'no front dashes']
		['Rainbow-',       false, 'no trailing dashes']
		['Ты блондинко йа одмин Тибя много йа адин'+
			' Ты на капсе йа пацтулом Щолкну мышкой плюсадин',
			false, 'not too long']
		['q',              false, 'not too short']
		['',               false, 'empty name - invalid name']
		[undefined,        false, 'empty name - invalid name']
		[null,             false, 'empty name - invalid name']
	]
		test.strictEqual validation.characterNameIsValid(name), result, message
