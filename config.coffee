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

# TODO: DEPRECATE: `config` and `config/test` should be used instead
module.exports =

	DATABASE_URL: process.env.DATABASE_URL or
		'postgres://anonymous:nopassword@localhost/uonline'
	DATABASE_URL_TEST: process.env.DATABASE_URL_TEST or
		'postgres://anonymous:nopassword@localhost/uonline_test'

	sessionLength: 64
	sessionExpireTime: 3600 # seconds
	userOnlineTimeout: 300 # seconds

	defaultInstanceForGuests: '/about/'
	defaultInstanceForUsers: '/game/'

	expStart: 1000
	expStep: 1000

	PERMISSIONS_USER: 'user'
	PERMISSIONS_ADMIN: 'admin'

	EXP_STEP: 1000
	EXP_MAX_START: 1000
