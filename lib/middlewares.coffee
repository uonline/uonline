'use strict'


transaction = require 'any-db-transaction'
{async, await} = require 'asyncawait'
promisifyAll = require("bluebird").promisifyAll


asyncMiddleware = (func) ->
	return (req, res, next) ->
		func(req, res).then((-> next()), next)

exports.asyncMiddleware = asyncMiddleware


exports.wrap = (func) ->
	return (req, res, next) ->
		func(req, res, next).catch(next)


exports.setInstance = (x) ->
	(request, response, next) ->
		request.uonline.instance = x
		next()


exports.render = (template) ->
	(request, response) ->
		response.render template, request.uonline


exports.redirect = (code, url) ->
	(request, response) ->
		response.redirect(code, url)


exports.openTransaction = (request, response, next) ->
	request.uonline.db = promisifyAll transaction(request.uonline.db)
	next()

exports.commit = asyncMiddleware async (request, response) ->
	await request.uonline.db.commitAsync()
