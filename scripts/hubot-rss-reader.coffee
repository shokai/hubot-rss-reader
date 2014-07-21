# Description:
#   Hubot RSS Reader
#
# Dependencies
#   "lodash":  "*"
#   "cheerio:  "*"
#   "request": "*"
#   "async":   "*"
#
# Commands:
#   hubot rss add https://github.com/shokai.atom
#   hubot rss delete http://shokai.org/blog/feed
#   hubot rss list
#
# Author:
#   @shokai
_ = require 'lodash'

module.exports = (robot) ->
  robot.brain.setAutoSave true

  getFeeds = (room) ->
    robot.brain.get("#{room}_feeds") or []

  setFeeds = (room, feeds) ->
    return unless feeds instanceof Array
    robot.brain.set "#{room}_feeds", feeds

  robot.respond /rss add (https?:\/\/[^\s]+)/i, (msg) ->
    url = msg.match[1].trim()
    feeds = getFeeds msg.message.room
    if _.contains feeds, url
      msg.send "#{url} is already registered"
      return
    feeds.push url
    setFeeds msg.message.room, feeds.sort()
    msg.send "registered #{url}"

  robot.respond /rss delete (https?:\/\/[^\s]+)/i, (msg) ->
    url = msg.match[1].trim()
    feeds = getFeeds msg.message.room
    unless _.contains feeds, url
      msg.send "#{url} is not registered"
      return
    feeds.splice feeds.indexOf(url), 1
    setFeeds msg.message.room, feeds
    msg.send "deleted #{url}"

  robot.respond /rss list/i, (msg) ->
    feeds = getFeeds msg.message.room
    if feeds.length < 1
      msg.send "nothing"
    else
      msg.send feeds.join "\n"

