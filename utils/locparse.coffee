crc32 = require 'buffer-crc32'
fs = require 'fs'


makeId = (str) ->
	crc32.signed(str) & 0x7FFFFFFF


warn = (pointer, str) ->
	if typeof pointer == 'number'
		pointer = "line #{pointer}"
	console.warn "WARN: #{pointer}: #{str}"


error = (pointer, str) ->
	if str is undefined
		str = pointer
		pointer = ''
	else
		if typeof pointer == 'number'
			pointer = "line #{pointer}"
		pointer += ': '
	throw new Erorr("#{pointer}#{str}")


checkSpaces = (line, lineNumber) ->
	if line.match(/\S\s+$/)? # warn 5
		warn lineNumber, 'trailing space(s)'
	
	if line.match(/^\s+\S/)? # warn 6
		warn lineNumber, 'starting space(s)'


isEmpty = (line, lineNumber) ->
	if line.match(/^\s+$/)? # warn 4
		warn lineNumber, 'line of spaces'
		return true
	
	return line == ''


makeMarkChecker = (re, mark) ->
	warnText = "starting '#{mark}' with no space after"
	(line, lineNumber) ->
		unless line.matches(re)
			return false
	
		unless line[mark.length] == ' '
			warn lineNumber, warnText
			return false
	
		return true

isAreaLabel = makeMarkChecker /^#/, '#'

isLocationLabel = makeMarkChecker /^###/, '###'

isListItem = makeMarkChecker /^\*/, '*'


Area = ->
	constructor: (@name, @label) ->
		console.log "New area #{@name}(#{@label})"
		@id = makeId @label
		@description = ''
		@locations = []
	return


Location = ->
	constructor: (@name, @label, @area) ->
		@id = makeId @label
		@description = ''
		@actions = []
	return


processMap = (filename, areaName, areaLabel) ->
	console.log "processing", filename
	lines = fs.readFileSync(filename, 'utf-8').split('\n')
	area = null
	location = null
	blankLines = 0
	for line, i in lines
		checkSpaces line, i
		
		if isEmpty(line, i)?
			blankLines++
			continue
		blankLines = 0
		
		if isAreaLabel(line, i)?
			if area? # error N
				error i, "area has been already defined"
			
			if blankLines > 0 # warn 7
				warn i, "#{blankLines} empty line(s) before area"
			
			localAreaName = line.substr(2)
			if areaName != localAreaName # error 5
				error i, "names from folder <#{areaName}> and from file <#{localAreaName}> don't match"
			
			area = new Area(areaName, areaLabel)
			areas.push(area)
			location = null
			continue
		else
			error i, "non-empty line before area defenition"
		
		if isLocationLabel(line, i)?
			[name, label, prop] = line.substr(4).split(/\s*`\s*/)
			
			if prop.trim() is '(default)' and defaultLocation? # error 11
				error i, "second default location found"
			
			location = new Location(name, label, area)
			area.locations.push(location)
			locations.push(location)
		
		if isListItem(line, i)?
			continue
		
		curObj = location || area
		error(i, "this should NEVER happen") unless curObj
		curObj.description += '\n' if blankLines > 1
		curObj.description += line

areas = []
locations = []
defaultLocation = null
exports.processDir = (dir) ->
	unless t = dir.match /\/([^\/]+)\s-\s([^\/]+)\/?$/ # error N
		error "wrong directory path <#{dir}>, folder must have name like 'Area name - label'"
	[_, name, label] = t
	
	checkSpaces name, 'name in folder name'
	checkSpaces label, 'label in folder name'
	
	files = fs.readdirSync(dir)
	for filename in files
		filepath = "#{dir}/#{filename}"
		if fs.statSync(filepath).isDirectory()
			processDir(filepath)
		else
			processMap(filepath)
	
	return

exports.processDir 'unify/Кронт - kront'
