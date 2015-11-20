# detect charset from "encoding" attribute of XML
# convert using iconv

'use strict'

stream = require 'stream'
Iconv  = require('iconv').Iconv
debug  = require('debug')('hubot-rss-reader:charset-convert-stream')

module.exports = ->

  iconv = null
  charset = null

  charsetConvertStream = stream.Transform()

  charsetConvertStream._transform = (chunk, enc, next) ->
    if charset is null and
       m = chunk.toString().match /<\?xml[^>]* encoding=['"]([^'"]+)['"]/
      charset = m[1]
      debug "charset: #{charset}"
      if charset.toUpperCase() isnt 'UTF-8'
        iconv = new Iconv charset, 'UTF-8//TRANSLIT//IGNORE'
    if iconv?
      @push iconv.convert(chunk)
    else
      @push chunk
    next()

  return charsetConvertStream

