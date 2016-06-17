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


module.exports =

	storage: [
		names: [
			'main'  # for core tests
			'pgp'  # for domain tests
		]
		type: 'pg-promise'
		params: process.env.DATABASE_URL_TEST or
			'postgres://anonymous:nopassword@localhost/uonline_test'
	]

	domain: [
		domain: 'account'
		type: 'pg'
		storage: 'main'
	]
