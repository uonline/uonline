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

crypto = require 'crypto'
fs = require 'fs'
sync = require 'sync'


# Create area's and location's numeric id from its label. Based on SHA-1.
# @return [Number]
makeId = (str) ->
	sum = crypto.createHash 'sha1'
	sum.update str
	(new Buffer(sum.digest('binary')).readUInt32LE(0)/2)|0


# Check if a given string is an area definition.
# @return [Boolean]
isAreaLabel = (line, lineNumber, log) ->
	return false unless line.match /^#[^#]/
	return true if line[1] is ' '
	log.warn(lineNumber, 'W1', "starting '#' with no space after") # warn 1
	return false


# Check if a given string is a location definition.
# @return [Boolean]
isLocationLabel = (line, lineNumber, log) ->
	return false unless line.match /^###/
	return true if line[3] is ' '
	log.warn(lineNumber, 'W2', "starting '###' with no space after") # warn 2
	return false


# Check if a given string is a list item definition.
# @return [Boolean]
isListItem = (line, lineNumber, log) ->
	return false if line[0] isnt '*'
	return true if line[1] is ' '
	log.warn(lineNumber, 'W3', "starting '*' with no space after") # warn 3
	return false


# Check if a given string is empty or contains only whitespaces.
# @return [Boolean]
isEmpty = (line, lineNumber, log) ->
	if line.match /^\s+$/
		log.warn lineNumber, 'W4', 'line of spaces' # warn 4
		return true
	return line is ''


# Check given string for trailing and leading whitespaces.
# Writes results to log.
checkSpaces = (line, lineNumber, log) ->
	log.warn lineNumber, 'W5', 'trailing space(s)' if line.match /\S\s+$/ # warn 5
	log.warn lineNumber, 'W6', 'starting space(s)' if line.match /^\s+\S/ # warn 6


# Check that all objects in array have different values in `propName`
# @return [Boolean]
checkPropUniqueness = (objs, pointer, errId, propName, log) ->
	propValuesSet = {}
	for obj in objs
		propValue = obj[propName]
		if propValue of propValuesSet
			log.error(
				pointer
				errId
				"both '#{propValuesSet[propValue]}' and '#{obj}' have same #{propName} <#{propValue}>"
			)
		propValuesSet[propValue] = obj


# Check consistency of parsed data.
# Writes results to log.
postCheck = (log) ->
	log.setFilename 'post processing'
	res = log.result

	checkPropUniqueness res.areas, 'areas', 'N/a', 'id', log # error N
	checkPropUniqueness res.locations, 'locations', 'N/a', 'id', log # error N
	checkPropUniqueness res.locations, 'locations', 'E7', 'label', log # error 7
	log.error 'locations', 'E6', "initial was not found" unless res.initialLocation? # error 6

	labels = {}
	labels[loc.label] = loc for loc in res.locations
	for loc in res.locations
		for target of loc.actions
			continue if target of labels
			log.error 'actions', 'E1', "target <#{target}> does not exist" # error 1


# Represents an area.
class Area

	# A constructor.
	constructor: (@name, @label) ->
		@id = makeId @label
		@description = ''
		@locations = []


# Represents a location.
class Location

	# A constructor.
	constructor: (@name, @label, @area) ->
		@id = makeId @label
		@description = ''
		@actions = {}
		@picture = null


# Logger. Collect and store log data.
# If verbose, prints warns and errors while collectiong.
# Also stores object with parsed data (may be not the best idea but one extra argument has gone).
class Logger

	# A constructor.
	constructor: (@result, @verbose) ->
		@filename = undefined

	# Adds "what" object in "toWhere" log group.
	_add: (toWhere, what) ->
		toWhere.push what
		if @filename of @result.files
			@result.files[@filename].push what
		else
			@result.files[@filename] = [what]

	# Set filename (or other string) to which next errors will be associated.
	setFilename: (filename) ->
		@filename = filename
		console.log " --- #{filename}:" if @verbose

	# Adds warning with:
	#  * pointer - something that can give an idea of warning cause location
	#  * id - identifier of warning (like "W1")
	#  * message - actual warning message
	# If verbose, prints it in console.
	warn: (pointer, id, message) ->
		pointer = "line #{pointer+1}" if typeof pointer == 'number'
		console.warn "Warning(#{id}): #{pointer}: #{message}" if @verbose
		@_add(
			@result.warnings
			id: id
			type: 'error'
			pointer: pointer
			message: message
		)

	# Like warn but for errors.
	error: (pointer, id, message) ->
		pointer = "line #{pointer+1}" if typeof pointer == 'number'
		console.warn "Error(#{id}): #{pointer}: #{message}" if @verbose
		@_add(
			@result.errors
			id: id
			type: 'warning'
			pointer: pointer
			message: message
		)


# Represents parsed data.
class Result
	verbose = false
	filename = undefined

	# A constructor.
	constructor: () ->
		@areas = []
		@locations = []
		@initialLocation = null
		@errors = []
		@warnings = []
		@files = {}

	# Save all the data to database using specified connection.
	save: (dbConnection) ->
		throw new Error("Can't save with errors.") if @errors.length > 0

		dbConnection.query.sync(dbConnection, "TRUNCATE areas", [])
		for area in @areas
			dbConnection.query.sync(
				dbConnection
				"INSERT INTO areas (id, title, description) VALUES ($1, $2, $3)"
				[area.id, area.name, area.description]
			)

		locByLabel = {}
		locByLabel[loc.label] = loc for loc in @locations

		dbConnection.query.sync(dbConnection, "TRUNCATE locations", [])
		for loc in @locations
			ways = ("#{v}=#{locByLabel[k].id}" for k,v of loc.actions)
			dbConnection.query.sync(
				dbConnection
				'INSERT INTO locations (id, title, description, area, initial, ways, picture) VALUES($1,$2,$3,$4,$5,$6,$7)'
				[loc.id, loc.name, loc.description, loc.area.id, (if loc is @initialLocation then 1 else 0),
					ways.join('|'), loc.picture]
			)


# Parse a `map.ht.md` file.
# Writes results to log.
processMap = (filename, areaName, areaLabel, log) ->
	log.setFilename filename
	lines = fs.readFileSync(filename, 'utf-8').split('\n')
	#throw new Error(lines)
	area = null
	location = null
	blankLines = 0
	for line, i in lines
		checkSpaces line, i, log

		if isEmpty(line, i, log)
			blankLines++
			continue

		if isAreaLabel(line, i, log)
			if area?
				log.error i, 'E12', "area has been already defined" # error 12
				i = blankLines # and W7 will not be spawned

			if blankLines < i
				log.warn i, 'W7', "skipped #{i-blankLines} non-empty line(s) before area" # warn 7

			localAreaName = line.substr(2)
			if areaName != localAreaName
				log.error i, 'E5', "names <#{areaName}>(folder) and <#{localAreaName}>(file) don't match" # error 5

			area = new Area(areaName, areaLabel)
			log.result.areas.push(area)
			location = null

		else if not area?
			continue # so we don't drop blankLines counter (for non-empty lines count, it's warn 7)

		else if isLocationLabel(line, i, log)
			[name, label, prop] = line.substr(4).split(/\s*`\s*/)

			unless label?
				log.error i, 'E3', "location should have `label` after name" # error 3
				label = ''
				prop = ''

			prop = prop.trim()

			label = area.label + '/' + label unless '/' in label

			location = new Location(name, label, area)

			if prop is '(initial)'
				log.error i, 'E11', "second initial location found" if log.result.initialLocation? # error 11
				log.result.initialLocation = location
			else if prop isnt ''
				log.warn i, 'W10', "text after location label will be ignored (#{prop})" # warn 10

			area.locations.push(location)
			log.result.locations.push(location)

		else if isListItem(line, i, log)
			unless location?
				log.error i, 'E13', "actions are only avaliable for locations" # error 13
				continue

			[name, target, rem] = line.substr(2).split(/\s*`\s*/)

			unless target?
				log.error i, 'E2', "action should have `label` after name" # error 2
				target = ''

			log.warn i, 'W8', "Unnecessary trailing dot" if name[name.length-1] is '.' # warn 8

			log.warn i, 'W10',"text after target label will be ignored (#{rem})" if rem? and rem isnt '' # warn 10

			target = location.area.label + '/' + target unless '/' in target

			log.warn i, 'W9', "action `#{target}` has been doubled" if target of location.actions # warn 9

			location.actions[target] = name

		else if (imageDescr=line.match /!\[(.+)\]\((.+)\)/ )?
			unless location?
				log.error i, 'E14', "images are only avaliable for locations" # error 14
				continue

			log.error i, 'E9', "location's image has been doubled" if location.picture? # error 9

			[_, path, path2] = imageDescr
			if path isnt path2
				log.error i, 'E10', "image paths are not equal: '#{path}', '#{path2}'" # error 10

			location.picture = path

		else
			curObj = location || area
			curObj.description += Array(blankLines+2).join("\n") if curObj.description isnt ''
			curObj.description += line

		blankLines = 0


# Process a directory with unify data.
# Writes results into log.
# For internal use.
processDir = (dir, parentLabel, log) ->
	log.setFilename dir

	unless t = dir.match /\/([^\/]+)\s-\s([^\/]+)\/?$/
		log.error 'dirname', 'E4', "wrong path <#{dir}>, folder must have name like 'Area name - label'" # error 4
		t = [null, dir, 'error'] # пусть хоть как-то дальше парсит, м.б. ещё какие ошибки нйдёт

	[_, name, label] = t
	label = parentLabel + '-' + label unless parentLabel is ''

	if log.result.areas.some((area) -> area.label == label)
		log.error 'loc.label', 'E15', "location with label <#{label}> already exists" # error 15

	checkSpaces name, 'name in folder name'
	checkSpaces label, 'label in folder name'

	files = fs.readdirSync(dir)
	for filename in files
		continue if filename[0] is '.' # what is hidden should be hidden
		filepath = "#{dir}/#{filename}"
		if fs.statSync(filepath).isDirectory()
			processDir(filepath, label, log)
		else
			processMap(filepath, name, label, log) if filename is 'map.ht.md' #.match /\.ht\.md$/


# Process a directory with unify data.
# For external use.
exports.processDir = (dir, verbose=false) ->
	log = new Logger(new Result(), verbose)
	processDir dir, '', log
	postCheck log
	log.result


exports.makeId = makeId
exports.isAreaLabel = isAreaLabel
exports.isLocationLabel = isLocationLabel
exports.isListItem = isListItem
exports.isEmpty = isEmpty
exports.checkSpaces = checkSpaces
exports.checkPropUniqueness = checkPropUniqueness
exports.postCheck = postCheck
