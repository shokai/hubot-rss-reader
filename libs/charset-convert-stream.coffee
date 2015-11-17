# detect charset from "encoding" attribute of XML
# convert using iconv

'use strict'

stream = require 'stream'
Iconv  = require('iconv').Iconv
debug  = require('debug')('hubot-rss-reader:charset-convert-stream')

module.exports = ->

  iconv = null

  charsetConvertStream = stream.Transform()

  charsetConvertStream._transform = (chunk, enc, next) ->
    if m = chunk.toString().match /<\?xml[^>]* encoding=['"]([^'"]+)['"]/
      debug charset = m[1]
      if charset.toUpperCase() isnt 'UTF-8'
        iconv = new Iconv charset, 'UTF-8//TRANSLIT//IGNORE'
    if iconv?
      @push iconv.convert(chunk)
    else
      @push chunk
    next()

  return charsetConvertStream

