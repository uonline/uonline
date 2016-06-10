NS = 'user'; exports[NS] = {}  # namespace
{test, requireCovered, config} = require '../../../lib/test-utils.coffee'

{async, await} = require 'asyncawait'
pgp = require('pg-promise')()
config = require '../../../config.coffee'

mg = require '../../../lib/migration.coffee'

User = requireCovered __dirname, '../../../domain/user/pg/index.coffee'
user = null
db_pool = pgp(config.DATABASE_URL)
db = null


exports[NS].before = async ->
	#await mg.migrate(_conn)

exports[NS].beforeEach = async ->
	db = await db_pool.connect()
	await db.none 'BEGIN'
	await db.none 'CREATE TABLE uniusers (id SERIAL, username TEXT)'
	user = new User(db)

exports[NS].afterEach = async ->
	await db.none 'ROLLBACK'
	db.done()


exports[NS].search =
	beforeEach: async ->
		await db.none 'INSERT INTO uniusers (username) VALUES ( $1 )', 'Sauron'
		this.user = {id:1, username:'Sauron'}

	existsName:
		'should return true if user exists': async ->
			test.isTrue (await user.existsName 'Sauron')
			test.isFalse (await user.existsName 'Sauron2')

		'should ignore capitalization': async ->
			test.isTrue (await user.existsName 'SAURON')
			test.isTrue (await user.existsName 'sauron')

	byName:
		'should return user data if user exists': async ->
			test.deepEqual (await user.byName 'Sauron'), this.user

		'should return null if user does not exist': async ->
			test.isNull (await user.byName 'Sauron2')

		'should ignore capitalization': async ->
			test.deepEqual (await user.byName 'SAURON'), this.user
			test.deepEqual (await user.byName 'sauron'), this.user

