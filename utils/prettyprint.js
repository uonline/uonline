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

var offset = 0;

exports.spaces = function(count){
	var s = '';
	for (var i=0; i<count; i++) s += ' ';
	return s;
};

exports.writeln = function(text, targetConsole){
	if (!targetConsole) targetConsole = console;
	targetConsole.log(this.spaces(offset) + text);
};

exports.section = function(name, targetConsole){
	if (!targetConsole) targetConsole = console;
	this.writeln(name + '...', targetConsole);
	offset += 2;
	return offset;
};

exports.endSection = function(){
	offset -= 2;
	return offset;
};

exports.action = function(name, targetFunction){
	if (!targetFunction) targetFunction = process.stdout.write;
	targetFunction(this.spaces(offset) + name + '...');
};

exports.result = function(result, targetConsole){
	if (!targetConsole) targetConsole = console;
	targetConsole.log(' ' + result);
};
