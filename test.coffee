fs = require 'fs'
ask = require 'require-r'
{async, await} = require 'asyncawait'

{config} = ask 'lib/test-utils.coffee'

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
			# NS = fpath.substr(0, fname.length-7)
			useDB[test.NS] = test.useDB
			exports[test.NS] = test[test.NS]
)('test/domain')


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
