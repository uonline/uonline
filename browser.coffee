# Common stuff
$(document).ready ->
	# Start up pjax
	$(document).pjax('a.pjax', '#content', timeout: 2000)
	$(document).on 'pjax:send', ->
		$('#content').animate opacity: 0.3, 'fast'
	$(document).on 'pjax:complete', ->
		$('#content').stop().css opacity: 1

	# Instance indication
	$('body').on 'click', '.instance-switcher', ->
		$('.instance-indicator').removeClass 'active'
		$(".instance-indicator[data-instance='#{this.dataset.instance}']").addClass 'active'

	# Registration page stuff

	# Selectors
	usernameField = 'input[name=user]'
	usernameFormGroup = '#user-form-group'
	usernameFeedback = '#username-feedback'
	passwordField = 'input[name=pass]'
	passwordFormGroup = '#password-form-group'
	passwordRevealButton = '#revealpass'
	passwordRevealIcon = '#revealpass i'
	# Deps
	validation = require './lib/validation.js'  # virtual name
	# Reveal password
	$("body").on 'click', passwordRevealButton, ->
		switch $(passwordField).prop('type')
			when 'password' then $(passwordField).prop 'type', 'text'
			else $(passwordField).prop 'type', 'password'
		$(passwordRevealButton).toggleClass 'active'
		$(passwordRevealIcon).toggleClass 'glyphicon-eye-close glyphicon-eye-open'
	# Password validation
	$("body").on 'change', passwordField, ->
		if validation.passwordIsValid($(passwordField).val())
			$(passwordFormGroup).removeClass 'has-error'
			$(passwordFormGroup).addClass 'has-success'
		else
			$(passwordFormGroup).removeClass 'has-success'
			$(passwordFormGroup).addClass 'has-error'
	# Username validation helper function
	usernameStatus = (state, hint) ->
		$(usernameFormGroup).removeClass 'has-error has-success'
		$(usernameFeedback).removeClass 'glyphicon-ok glyphicon-remove glyphicon-refresh'
		$(usernameFeedback).hide()
		# state
		if state is 'checking'
			$(usernameFeedback).addClass 'glyphicon-refresh'
			$(usernameFeedback).show()
		if state is 'ok'
			$(usernameFeedback).addClass 'glyphicon-ok'
			$(usernameFeedback).show()
			$(usernameFormGroup).addClass 'has-success'
		if state is 'error'
			$(usernameFeedback).addClass 'glyphicon-remove'
			$(usernameFeedback).show()
			$(usernameFormGroup).addClass 'has-error'
		# hint
		if not hint? then hint = ''
		$(usernameFeedback).attr('title', hint)
	# Username validation
	$("body").on 'change', usernameField, ->
		if validation.usernameIsValid($(usernameField).val())
			usernameStatus 'checking', 'Проверяем, свободен ли логин'
			$.getJSON "/ajax/isNickBusy/#{encodeURIComponent($(usernameField).val())}", (data) ->
				if data.nick != $(usernameField).val()
					usernameStatus 'empty'
					return
				if data.isNickBusy
					usernameStatus 'error', 'Такой логин уже занят'
				else
					usernameStatus 'ok', 'Логин свободен'
		else
			usernameStatus 'error', 'Логин неправильный'