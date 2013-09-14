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

exports.writeln = function(text){
	console.log(this.spaces(offset) + text);
};

exports.section = function(name){
	this.writeln(name + '...');
	offset += 2;
};

exports.endSection = function(){
	offset -= 2;
};

exports.action = function(name){
	console.log(this.spaces(offset) + name + '...'); // must be: no newline!
};

exports.result = function(result){
	console.log(' ' + result);
};
