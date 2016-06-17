fs = require 'fs'
ask = require 'require-r'
{async, await} = require 'asyncawait'

{config} = ask 'lib/test-utils.coffee'
TESTS_DIR = 'tests'

pgPool = null
pg = null
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
	pgPool = (await ask('storage').spawn(config.storage)).pgTest
	pg = await pgPool.connect()
	for NS of useDB
		useDB[NS]({pg})


exports.after = async ->
	pg.done()
