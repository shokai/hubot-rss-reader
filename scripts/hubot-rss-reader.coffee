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

## config
process.env.HUBOT_RSS_INTERVAL ||= 60*10  # 10 minutes
process.env.HUBOT_RSS_HEADER   ||= ':sushi:'

module.exports = (robot) ->

  checker = new RSSChecker robot

  ## wait until connect redis
  setTimeout ->
    run = (opts) ->
      checker.check opts
      .then ->
        debug "wait #{process.env.HUBOT_RSS_INTERVAL} seconds"
        setTimeout run, 1000 * process.env.HUBOT_RSS_INTERVAL
      , (err) ->
        debug err
        debug "wait #{process.env.HUBOT_RSS_INTERVAL} seconds"
        setTimeout run, 1000 * process.env.HUBOT_RSS_INTERVAL

    run {init: yes}
  , 10000

  last_state_is_error = {}

  checker.on 'new entry', (entry) ->
    last_state_is_error[entry.feed.url] = false
    for room, feeds of checker.getAllFeeds()
      if room isnt entry.args.room and
         _.include feeds, entry.feed.url
        debug "#{entry.title} #{entry.url} => #{room}"
        try
          robot.send? {room: room}, entry.toString()
        catch err
          debug "Error on sending to room: \"#{room}\""
          debug err

  checker.on 'error', (err) ->
    debug err
    if last_state_is_error[err.feed.url]  # reduce error notify
      return
    last_state_is_error[err.feed.url] = true
    for room, feeds of checker.getAllFeeds()
      if _.include feeds, err.feed.url
        try
          robot.send? {room: room}, "[ERROR] #{err.feed.url} - #{err.error.message or err.error}"
        catch err
          debug "Error on sending to room: \"#{room}\""
          debug err

  robot.respond /rss\s+(add|register)\s+(https?:\/\/[^\s]+)$/im, (msg) ->
    url = msg.match[2].trim()
    last_state_is_error[url] = false
    debug "add #{url}"
    checker.addFeed msg.message.room, url
    .then (res) ->
      new Promise (resolve) ->
        msg.send res
        resolve url
    .then (url) ->
      checker.fetch {url: url, room: msg.message.room}
    .then (entries) ->
      for entry in entries
        msg.send entry.toString()
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
      debug err.stack


  robot.respond /rss\s+delete\s+(https?:\/\/[^\s]+)$/im, (msg) ->
    url = msg.match[1].trim()
    debug "delete #{url}"
    checker.deleteFeed msg.message.room, url
    .then (res) ->
      msg.send res
    .catch (err) ->
      msg.send err
      debug err.stack

  robot.respond /rss\s+delete\s+#([^\s]+)$/im, (msg) ->
    room = msg.match[1].trim()
    debug "delete ##{room}"
    checker.deleteRoom room
    .then (res) ->
      msg.send res
    .catch (err) ->
      msg.send err
      debug err.stack

  robot.respond /rss\s+list$/i, (msg) ->
    feeds = checker.getFeeds msg.message.room
    if feeds.length < 1
      msg.send "nothing"
    else
      msg.send feeds.join "\n"

  robot.respond /rss dump$/i, (msg) ->
    feeds = checker.getAllFeeds()
    msg.send JSON.stringify feeds, null, 2
