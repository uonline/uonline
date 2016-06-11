NS = 'domain/account/pg'; exports[NS] = {}  # namespace
{test, requireCovered, config} = require '../../../lib/test-utils.coffee'

{async, await} = require 'asyncawait'
pgp = require('pg-promise')()
config = require '../../../config.coffee'

mg = require '../../../lib/migration.coffee'

Account = requireCovered __dirname, '../../../domain/account/pg/index.coffee'
account = null
db_pool = pgp(config.DATABASE_URL_TEST)
db = null


exports[NS].before = async ->
	db = await db_pool.connect()
	#await mg.migrate(_conn)
	account = new Account(db)

exports[NS].beforeEach = async ->
	await db.none 'BEGIN'
	await db.none 'CREATE TABLE account (id SERIAL, name TEXT)'

exports[NS].afterEach = async ->
	await db.none 'ROLLBACK'

exports[NS].after = async ->
	db.done()


exports[NS].search =
	beforeEach: async ->
		await db.none 'INSERT INTO account (name) VALUES ($1)', 'Sauron'
		this.user = { id:1, name:'Sauron' }

	existsName:
		'should return true if user exists': async ->
			test.isTrue (await account.existsName 'Sauron')
			test.isFalse (await account.existsName 'Sauron2')

		'should ignore capitalization': async ->
			test.isTrue (await account.existsName 'SAURON')
			test.isTrue (await account.existsName 'sauron')

	byName:
		'should return user data if user exists': async ->
			test.deepEqual (await account.byName 'Sauron'), this.user

		'should return null if user does not exist': async ->
			test.isNull (await account.byName 'Sauron2')

		'should ignore capitalization': async ->
			test.deepEqual (await account.byName 'SAURON'), this.user
			test.deepEqual (await account.byName 'sauron'), this.user

