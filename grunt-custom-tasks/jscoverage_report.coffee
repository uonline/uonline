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

module.exports = (grunt) ->
	# Please see the Grunt documentation for more information regarding task
	# creation: http://gruntjs.com/creating-tasks
	grunt.registerTask 'jscoverage_report', 'Show jscoverage report.', ->
		showOnly = @options().showOnly
		# filter
		if showOnly?
			files = Object.keys(_$jscoverage)
			shallDelete = files.filter (x) -> not x.match(showOnly)
			for key in shallDelete
				delete _$jscoverage[key]
		# out
		exports.coverageDetail()


#############################################################
# Everything below is borrowed from old version of jscoverage
# and converted with js2coffee with no changes.
#############################################################

processLinesMask = (lines) ->
	processLeft3 = (arr, offset) ->
		prev1 = offset - 1
		prev2 = offset - 2
		prev3 = offset - 3
		return  if prev1 < 0
		arr[prev1] = (if arr[prev1] is 1 then arr[prev1] else 2)
		return  if prev2 < 0
		arr[prev2] = (if arr[prev2] is 1 then arr[prev2] else 2)
		return  if prev3 < 0
		arr[prev3] = (if arr[prev3] then arr[prev3] else 3)
		return
	processRight3 = (arr, offset) ->
		len = arr.length
		next1 = offset
		next2 = offset + 1
		next3 = offset + 2
		return  if next1 >= len or arr[next1] is 1
		arr[next1] = (if arr[next1] then arr[next1] else 2)
		return  if next2 >= len or arr[next2] is 1
		arr[next2] = (if arr[next2] then arr[next2] else 2)
		return  if next3 >= len or arr[next3] is 1
		arr[next3] = (if arr[next3] then arr[next3] else 3)
		return
	offset = 0
	now = undefined
	prev = 0
	while offset < lines.length
		now = lines[offset]
		now = (if now isnt 1 then 0 else 1)
		if now isnt prev
			if now is 1
				processLeft3 lines, offset
			else processRight3 lines, offset  if now is 0
		prev = now
		offset++
	lines


printCoverageDetail = (lines, source) ->
	echo = (lineNum, str, bool) ->
		console.log colorful(lineNum, "LINENUM") + "|" + colorful(str, (if bool then "YELLOW" else "GREEN"))
		return
	len = lines.length
	lines = processLinesMask(lines)
	i = 1

	while i < len
		if lines[i] isnt 0
			if lines[i] is 3
				console.log "......"
			else if lines[i] is 2
				echo i, source[i - 1], false
			else
				echo i, source[i - 1], true
		i++
	return


colorful = (str, type) ->
	head = "\u001b["
	foot = "\u001b[0m"
	color =
		LINENUM: 36
		GREEN: 32
		YELLOW: 33
		RED: 31

	head + color[type] + "m" + str + foot


exports.coverage = ->
	file = undefined
	tmp = undefined
	total = undefined
	touched = undefined
	n = undefined
	len = undefined
	return  if typeof _$jscoverage is "undefined"
	for i of _$jscoverage
		file = i
		tmp = _$jscoverage[i]
		continue  if typeof tmp is "function" or tmp.length is undefined
		total = touched = 0
		n = 0
		len = tmp.length
		while n < len
			if tmp[n] isnt undefined
				total++
				touched++  if tmp[n] > 0
			n++
		console.log "[JSCOVERAGE] "+file+":"+
			((if total then (((touched / total) * 100).toFixed(2) + "%") else "Not prepared!!!"))
	return


exports.coverageDetail = ->
	file = undefined
	tmp = undefined
	source = undefined
	lines = undefined
	allcovered = undefined
	return  if typeof _$jscoverage is "undefined"
	for i of _$jscoverage
		file = i
		tmp = _$jscoverage[i]
		continue  if typeof tmp is "function" or tmp.length is undefined
		source = tmp.source
		allcovered = true
		lines = []
		n = 0
		len = source.length
		while n < len
			if tmp[n] is 0
				lines[n] = 1
				allcovered = false
			else
				lines[n] = 0
			n++
		if allcovered
			console.log colorful("[ 100% COVERED ]", "GREEN"), file
		else
			console.log colorful("[UNCOVERED CODE]", "RED"), file
			printCoverageDetail lines, source
	return
