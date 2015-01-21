# Description:
#   Hubot RSS Reader
#
# Commands:
#   hubot rss add https://github.com/shokai.atom
#   hubot rss delete http://shokai.org/blog/feed
#   hubot rss delete #room_name
#   hubot rss list
#   hubot rss dump
#
# Author:
#   @shokai

'use strict'

path       = require 'path'
_          = require 'lodash'
debug      = require('debug')('hubot-rss-reader')
Promise    = require 'bluebird'
RSSChecker = require path.join __dirname, '../libs/rss-checker'
FindRSS    = Promise.promisify require 'find-rss'
Entities   = require 'html-entities'
entities   = new Entities.XmlEntities()

## config
process.env.HUBOT_RSS_INTERVAL ||= 60*10  # 10 minutes
process.env.HUBOT_RSS_HEADER   ||= ':sushi:'

module.exports = (robot) ->

  logger =
    info: (msg) ->
      return debug msg if debug.enabled
      msg = JSON.stringify msg if typeof msg isnt 'string'
      robot.logger.info "#{debug.namespace}: #{msg}"
    error: (msg) ->
      return debug msg if debug.enabled
      msg = JSON.stringify msg if typeof msg isnt 'string'
      robot.logger.error "#{debug.namespace}: #{msg}"

  send_queue = []
  send = (envelope, body) ->
    send_queue.push {envelope: envelope, body: body}

  setInterval ->
    return if typeof robot.send isnt 'function'
    return if send_queue.length < 1
    msg = send_queue.shift()
    try
      robot.send msg.envelope, msg.body
    catch err
      logger.error "Error on sending to room: \"#{room}\""
      logger.error err
  , 500

  checker = new RSSChecker robot

  ## wait until connect redis
  robot.brain.once 'loaded', ->
    run = (opts) ->
      logger.info "checker start"
      checker.check opts
      .then ->
        logger.info "wait #{process.env.HUBOT_RSS_INTERVAL} seconds"
        setTimeout run, 1000 * process.env.HUBOT_RSS_INTERVAL
      , (err) ->
        logger.error err
        logger.info "wait #{process.env.HUBOT_RSS_INTERVAL} seconds"
        setTimeout run, 1000 * process.env.HUBOT_RSS_INTERVAL

    run {init: yes}


  last_state_is_error = {}

  checker.on 'new entry', (entry) ->
    last_state_is_error[entry.feed.url] = false
    for room, feeds of checker.getAllFeeds()
      if room isnt entry.args.room and
         _.include feeds, entry.feed.url
        logger.info "#{entry.title} #{entry.url} => #{room}"
        message = entities.decode entry.toString()
        send {room: room}, message

  checker.on 'error', (err) ->
    logger.error err
    if last_state_is_error[err.feed.url]  # reduce error notify
      return
    last_state_is_error[err.feed.url] = true
    for room, feeds of checker.getAllFeeds()
      if _.include feeds, err.feed.url
        send {room: room}, "[ERROR] #{err.feed.url} - #{err.error.message or err.error}"

  robot.respond /rss\s+(add|register)\s+(https?:\/\/[^\s]+)$/im, (msg) ->
    url = msg.match[2].trim()
    last_state_is_error[url] = false
    logger.info "add #{url}"
    checker.addFeed msg.message.room, url
    .then (res) ->
      new Promise (resolve) ->
        msg.send res
        resolve url
    .then (url) ->
      checker.fetch {url: url, room: msg.message.room}
    .then (entries) ->
      for entry in entries.splice(0,5)
        message = entities.decode entry.toString()
        send {room: msg.message.room}, message
      if entries.length > 0
        send {room: msg.message.room},
        "#{process.env.HUBOT_RSS_HEADER} #{entries.length} entries has been omitted"
    , (err) ->
      msg.send "[ERROR] #{err}"
      return if err.message isnt 'Not a feed'
      checker.deleteFeed msg.message.room, url
      .then ->
        FindRSS url
      .then (feeds) ->
        return if feeds?.length < 1
        msg.send _.flatten([
          "found some Feeds from #{url}"
          feeds.map (i) -> " * #{i.url}"
        ]).join '\n'
    .catch (err) ->
      msg.send "[ERROR] #{err}"
      logger.error err.stack


  robot.respond /rss\s+delete\s+(https?:\/\/[^\s]+)$/im, (msg) ->
    url = msg.match[1].trim()
    logger.info "delete #{url}"
    checker.deleteFeed msg.message.room, url
    .then (res) ->
      msg.send res
    .catch (err) ->
      msg.send err
      logger.error err.stack

  robot.respond /rss\s+delete\s+#([^\s]+)$/im, (msg) ->
    room = msg.match[1].trim()
    logger.info "delete ##{room}"
    checker.deleteRoom room
    .then (res) ->
      msg.send res
    .catch (err) ->
      msg.send err
      logger.error err.stack

  robot.respond /rss\s+list$/i, (msg) ->
    feeds = checker.getFeeds msg.message.room
    if feeds.length < 1
      msg.send "nothing"
    else
      msg.send feeds.join "\n"

  robot.respond /rss dump$/i, (msg) ->
    feeds = checker.getAllFeeds()
    msg.send JSON.stringify feeds, null, 2
