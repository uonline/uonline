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

# Common stuff
$(document).ready ->
	# Start up pjax
	$(document).pjax('a.pjax', '#content', timeout: 2000)
	$(document).pjax('a.pjax-replace', '#content', timeout: 2000, replace: true)
	$(document).on 'pjax:send', ->
		$('#content').animate opacity: 0.3, 'fast'
	$(document).on 'pjax:complete', ->
		$('#content').stop().css opacity: 1

	# Help on profile page
	$('.profile-help').hide()
	$(document).on 'pjax:complete', ->
		$('.profile-help').hide()
	$('body').on 'click', '.profile-help-switcher', ->
		$('.profile-help-switcher').toggleClass 'active'
		$('.profile-help').toggle()

	# Buttons with confirmation
	$('body').on 'click', '.confirm', (event) ->
		if confirm('Вы уверены?') == false
			event.preventDefault()
		return

	# Common func for user and character name checking
	nameStatusHelper = (formGroupSelector, feedbackSelector) ->
		(state, hint) ->
			# init
			formGroup = $(formGroupSelector)
			feedback = $(feedbackSelector)
			# cleanup
			formGroup.removeClass 'has-error has-success'
			feedback.removeClass 'glyphicon-ok glyphicon-remove glyphicon-refresh'
			feedback.hide()
			# state
			if state is 'checking'
				feedback.addClass 'glyphicon-refresh'
				feedback.show()
			if state is 'ok'
				feedback.addClass 'glyphicon-ok'
				feedback.show()
				formGroup.addClass 'has-success'
			if state is 'error'
				feedback.addClass 'glyphicon-remove'
				feedback.show()
				formGroup.addClass 'has-error'
			# hint
			if not hint? then hint = ''
			feedback.attr('title', hint)

	# Registration page stuff

	# Selectors
	usernameField = 'input[name=username]'
	usernameFormGroup = '#username-form-group'
	usernameFeedback = '#username-feedback'
	passwordField = 'input[name=password]'
	passwordFormGroup = '#password-form-group'
	passwordRevealButton = '#revealpass'
	passwordRevealIcon = '#revealpass i'
	# Deps
	validation = require 'validation'
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
	# Username validation
	usernameStatus = nameStatusHelper(usernameFormGroup, usernameFeedback)
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

	# Character name validation
	charnameStatus = nameStatusHelper('#character-name-form-group', '#character-name-feedback')
	$("body").on 'change', '#character-name', ->
		name = this.value
		if validation.characterNameIsValid(name)
			charnameStatus 'checking', 'Проверяем, свободно ли имя'
			$.getJSON "/ajax/isCharacterNameBusy/#{encodeURIComponent(name)}", (data) ->
				if data.name != name
					charnameStatus 'empty'
					return
				if data.isCharacterNameBusy
					charnameStatus 'error', 'Такое имя уже занято'
				else
					charnameStatus 'ok', 'Имя свободно'
		else
			charnameStatus 'error', 'Имя неправильное'
