crc32 = require 'buffer-crc32'
fs = require 'fs'


makeId = (str) ->
	crc32.signed(str) & 0x7FFFFFFF


warn = (pointer, str) ->
	if typeof pointer == 'number'
		pointer = "line #{pointer}"
	console.warn "Warning: #{pointer}: #{str}"


error = (pointer, str) ->
	if str is undefined
		str = pointer
		pointer = ''
	else
		if typeof pointer == 'number'
			pointer = "line #{pointer}"
		pointer += ': '
	throw new Error("#{pointer}#{str}")


checkSpaces = (line, lineNumber) ->
	if line.match(/\S\s+$/)? # warn 5
		warn lineNumber, 'trailing space(s)'
	
	if line.match(/^\s+\S/)? # warn 6
		warn lineNumber, 'starting space(s)'


isEmpty = (line, lineNumber) ->
	if line.match(/^\s+$/)? # warn 4
		warn lineNumber, 'line of spaces'
		return true
	
	return line is ''


makeMarkChecker = (re, mark) ->
	warnText = "starting '#{mark}' with no space after"
	(line, lineNumber) ->
		unless line.match(re)
			return false
	
		unless line[mark.length] == ' '
			warn lineNumber, warnText+line
			return false
	
		return true

isAreaLabel = makeMarkChecker /^#[^#]/, '#'

isLocationLabel = makeMarkChecker /^###/, '###'

isListItem = makeMarkChecker /^\*[^\*]/, '*'


class Area
	constructor: (@name, @label) ->
		@id = makeId @label
		@description = ''
		@locations = []


class Location
	constructor: (@name, @label, @area) ->
		@id = makeId @label
		@description = ''
		@actions = {}


processMap = (filename, areaName, areaLabel) ->
	lines = fs.readFileSync(filename, 'utf-8').split('\n')
	area = null
	location = null
	blankLines = 0
	for line, i in lines
		checkSpaces line, i
		
		if isEmpty(line, i)
			blankLines++
			continue
		
		if isAreaLabel(line, i)
			if area? # error N
				error i, "area has been already defined"
			
			if blankLines < i # warn 7
				warn i, "#{i-blankLines} skipped line(s) before area"
			
			localAreaName = line.substr(2)
			if areaName != localAreaName # error 5
				error i, "names from folder <#{areaName}> and from file <#{localAreaName}> don't match"
			
			area = new Area(areaName, areaLabel)
			exports.areas.push(area)
			location = null
		else if not area?
			# ...
		else if isLocationLabel(line, i)
			[name, label, prop] = line.substr(4).split(/\s*`\s*/)
			
			unless '/' in label
				label = area.label + '/' + label
			
			location = new Location(name, label, area)
			
			if prop.trim() is '(default)'
				error i, "second default location found" if exports.defaultLocation? # error 11
				exports.defaultLocation = location
			
			area.locations.push(location)
			exports.locations.push(location)
		else if isListItem(line, i)
			unless location?
				error i, "actions are only avaliable for locations"
			
			[name, target, rem] = line.substr(2).split(/\s*`\s*/)
			
			if rem is not ''
				warn i, "text after target label will be ignored (#{rem})"
			
			unless '/' in target
				target = location.area.label + '/' + target
			
			location.actions[target] = name
		else
			curObj = location || area
			curObj.description += '\n' if blankLines >= 1 and curObj.description isnt ''
			curObj.description += line
		
		blankLines = 0


exports.reset = () ->
	exports.areas = []
	exports.locations = []
	exports.defaultLocation = null
exports.reset()

exports.processDir = (dir, parentLabel='') ->
	unless t = dir.match /\/([^\/]+)\s-\s([^\/]+)\/?$/ # error N
		error "wrong directory path <#{dir}>, folder must have name like 'Area name - label'"
	[_, name, label] = t
	label = parentLabel + '-' + label unless parentLabel is ''
	
	checkSpaces name, 'name in folder name'
	checkSpaces label, 'label in folder name'
	
	files = fs.readdirSync(dir)
	for filename in files
		filepath = "#{dir}/#{filename}"
		if fs.statSync(filepath).isDirectory()
			exports.processDir(filepath, label)
		else
			processMap(filepath, name, label) if filename is 'map.ht.md' #.match /\.ht\.md$/

#exports.processDir 'unify/Кронт - kront'
