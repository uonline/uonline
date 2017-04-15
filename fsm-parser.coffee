tokens = [
	id: 'LOCATION'
	regex: /^\#\#\#\s?(.*)\s[`]([-_a-z0-9]+)[`]$/
	requiresState: ['area', 'location', 'location_with_image']
	process: (state, input) -> console.log "Our location is called #{input[1]}, and its label is #{input[2]}"
	switchesToState: 'location'
,
	id: 'AREA'
	regex: /^[#]\s?(.*)$/
	requiresState: 'init'
	process: (state, input) -> console.log "Our area is called #{input[1]}"
	switchesToState: 'area'
,
	id: 'IMAGE'
	regex: /^!\[(.*)\]\(\1\)$/
	requiresState: 'location'
	process: (state, input) -> console.log "Our image is #{input[1]}"
	switchesToState: 'location_with_image'
,
	id: 'ACTION'
	regex: /^[*]\s(.*)\s[`]([-_/a-z0-9]+)[`]$/
	requiresState: ['location', 'location_with_image']
	process: (state, input) -> console.log "Our action is #{input[1]}, and it leads to #{input[2]}"
	switchesToState: null
,
	id: 'TEXT'
	regex: /^(.*)$/
	requiresState: ['area', 'location', 'location_with_image']
	process: (state, input) -> console.log "Our text is #{input[1]}"
	switchesToState: null
]

lines = [
	'# Kront'
	'It is now or never'
	'I am not gonna live forever'
	'### fdf `lol`'
	'![well.jpg](well.jpg)'
	'I am not gonna live forever'
	'* Kill Bill `billy-state`'
	'yes'
]

currentState = 'init'
for line in lines
	console.log "> #{line}"
	for token in tokens
		if token.regex.test(line)
			console.log "Token type: #{token.id}"
			stateIsSuitable = false
			if typeof token.requiresState is 'string'
				stateIsSuitable = (token.requiresState is currentState)
			else
				for onePossibleState in token.requiresState
					if currentState is onePossibleState
						stateIsSuitable = true
			if stateIsSuitable
				token.process(currentState, line.match(token.regex))
				if token.switchesToState?
					currentState = token.switchesToState
			else
				console.log "Unexpected token: #{token.id}"
				return
			break
