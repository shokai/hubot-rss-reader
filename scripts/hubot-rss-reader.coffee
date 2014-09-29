# Description:
#   Hubot RSS Reader
#
# Dependencies
#   "async":      "*"
#   "feedparser": "*"
#   "lodash":     "*"
#   "request":    "*"
#
# Commands:
#   hubot rss add https://github.com/shokai.atom
#   hubot rss delete http://shokai.org/blog/feed
#   hubot rss list
#
# Author:
#   @shokai

path       = require 'path'
_          = require 'lodash'
debug      = require('debug')('hubot-rss-reader')
RSSFinder  = require 'find-rss'
RSSChecker = require path.join __dirname, '../libs/rss-checker'

## config
process.env.HUBOT_RSS_INTERVAL ||= 60*10  # 10 minutes
process.env.HUBOT_RSS_HEADER   ||= ':sushi:'

module.exports = (robot) ->

  checker = new RSSChecker robot

  ## wait until connect redis
  setTimeout ->
    run = (opts) ->
      checker.check opts, ->
        debug "wait #{process.env.HUBOT_RSS_INTERVAL} seconds"
        setTimeout run, 1000 * process.env.HUBOT_RSS_INTERVAL

    run {init: yes}
  , 10000

  last_state_is_error = {}

  checker.on 'new entry', (entry) ->
    last_state_is_error[entry.feed.url] = false
    for room, feeds of robot.brain.get('feeds')
      if _.include feeds, entry.feed.url
        debug "#{entry.title} #{entry.url} => #{room}"
        robot.messageRoom '#'+room, entry.toString()

  checker.on 'error', (err) ->
    debug err
    if last_state_is_error[err.feed.url]  # reduce error notify
      return
    last_state_is_error[err.feed.url] = true
    for room, feeds of robot.brain.get('feeds')
      if _.include feeds, err.feed.url
        robot.messageRoom '#'+room, "[ERROR] #{err.feed.url} - #{err.error.message}"

  robot.respond /rss\s+(add|register)\s+(https?:\/\/[^\s]+)/im, (msg) ->
    url = msg.match[2].trim()
    last_state_is_error[url] = false
    debug "add #{url}"
    checker.addFeed msg.message.room, url, (err, res) ->
      if err
        msg.send err
        return
      msg.send res
      checker.fetch url, (err, entries) ->
        unless err
          for entry in entries
            msg.send entry.toString()
          return
        msg.send err
        if err.message is 'Not a feed'
          checker.deleteFeed msg.message.room, url
          RSSFinder url, (err, feeds) ->
            return if err or feeds?.length < 1
            msg.send _.flatten([
              "found some Feeds from #{url}"
              feeds.map (i) -> " * #{i.url}"
            ]).join '\n'
        return

  robot.respond /rss\s+delete\s+(https?:\/\/[^\s]+)/im, (msg) ->
    url = msg.match[1].trim()
    debug "delete #{url}"
    checker.deleteFeed msg.message.room, url, (err, res) ->
      if err
        return msg.send err
      msg.send res

  robot.respond /rss\s+list/i, (msg) ->
    feeds = checker.getFeeds msg.message.room
    if feeds.length < 1
      msg.send "nothing"
    else
      msg.send feeds.join "\n"
