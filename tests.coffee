fs = require 'fs'
ask = require 'require-r'
{async, await} = require 'asyncawait'

{config} = ask 'lib/test-utils.coffee'
TESTS_DIR = 'tests'

dbPool = null
db = null
useDB = {}


(iter = (dirname) ->
	for fname in fs.readdirSync(dirname)
		fpath = dirname+'/'+fname
		if fs.statSync(fpath).isDirectory()
			iter(fpath)
		else if fname.endsWith('.coffee')
			test = ask fpath
			NS = fpath.substring(TESTS_DIR.length+1, fpath.length-7)
			console.log(fpath, fname, NS)
			useDB[NS] = test.useDB
			delete test.useDB
			exports[NS] = test
)(TESTS_DIR)


exports.before = async ->
	dbPool = (await ask('storage').spawn(config.storage)).pgTest
	db = await dbPool.connect()
	for NS of useDB
		useDB[NS](db)


exports.beforeEach = async ->
	await db.none 'BEGIN'


exports.afterEach = async ->
	await db.none 'ROLLBACK'


exports.after = async ->
	db.done()
