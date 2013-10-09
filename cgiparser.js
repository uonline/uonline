/*
 *
 * (The MIT License)
 *
 * Copyright (c) 2012 Nathan Rajlich nathan@tootallnate.net
 * Copyright (c) 2013 m1kc m1kc@yandex.ru
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files
 * (the 'Software'), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall
 * be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
 * AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */


"use strict";

var Stream = require('stream').Stream;
var StreamStack = require('stream-stack').StreamStack;
var HeaderParser = require('header-stack').Parser;

/**
 * Parses CGI headers (\n newlines) until a blank line,
 * signifying the end of the headers. After the blank line
 * is assumed to be the body, which you can use 'pipe()' with.
 */
function Parser(stream) {
  StreamStack.call(this, stream, {
    data: function(b) { this._onData(b); }
  });
  this._onData = this._parseHeader;
  this._headerParser = new HeaderParser(new Stream(), {
    emitFirstLine: false,
    strictCRLF: false,
    strictSpaceAfterColon: false,
    allowFoldedHeaders: false
  });
  this._headerParser.on('headers', this._onHeadersComplete.bind(this));
}
require('util').inherits(Parser, StreamStack);
module.exports = Parser;

Parser.prototype._proxyData = function(b) {
  this.emit('data', b);
};

Parser.prototype._parseHeader = function(chunk) {
  this._headerParser.stream.emit('data', chunk);
};

Parser.prototype._onHeadersComplete = function(headers, leftover) {
  this._onData = this._proxyData;
  this.emit('headers', headers);
  if (leftover) {
    this._onData(leftover);
    this.emit('leftover',leftover); // added by m1kc
  }
};
