# Description:
#   Hubot RSS Reader
#
# Dependencies
#   "lodash":      "*"
#   "rss-watcher": "*"
#
# Commands:
#   hubot rss add https://github.com/shokai.atom
#   hubot rss delete http://shokai.org/blog/feed
#   hubot rss list
#
# Author:
#   @shokai

_ = require 'lodash'
RSSWatcher = require 'rss-watcher'

watchers = new class Watchers
  constructor: ->
    @watchers = {}

  watch: (url) ->
    return @watchers[url] ||= (
      w = new RSSWatcher(url)
      w.run()
      w
    )

  stop: (url) ->
    if w = @watchers[url]
      w.stop()


module.exports = (robot) ->

  getFeeds = (room) ->
    robot.brain.get('feeds')?[room] or []

  setFeeds = (room, urls) ->
    return unless urls instanceof Array
    feeds = robot.brain.get('feeds') or {}
    feeds[room] = urls
    robot.brain.set 'feeds', feeds

  ## should run after redis connected
  setTimeout ->
    for room, urls of robot.brain.get('feeds')
      for url in urls
        watcher = watchers.watch url
        watcher.on 'error', (err) ->
          robot.send {room: room}, err
        watcher.on 'new article', (article) ->
          robot.send {room: room}, "#{article.title}\n#{article.link}"
  , 3000

  robot.respond /rss add (https?:\/\/[^\s]+)/i, (msg) ->
    url = msg.match[1].trim()
    feeds = getFeeds msg.message.room
    if _.contains feeds, url
      msg.send "#{url} is already registered"
      return
    feeds.push url
    setFeeds msg.message.room, feeds.sort()
    watcher = watchers.watch(url)
    watcher.on 'error', (err) ->
      msg.send err
    watcher.on 'new article', (article) ->
      msg.send "#{article.title}\n#{article.link}"
    msg.send "registered #{url}"

  robot.respond /rss delete (https?:\/\/[^\s]+)/i, (msg) ->
    url = msg.match[1].trim()
    feeds = getFeeds msg.message.room
    unless _.contains feeds, url
      msg.send "#{url} is not registered"
      return
    feeds.splice feeds.indexOf(url), 1
    setFeeds msg.message.room, feeds
    watchers.stop url
    msg.send "deleted #{url}"

  robot.respond /rss list/i, (msg) ->
    feeds = getFeeds msg.message.room
    if feeds.length < 1
      msg.send "nothing"
    else
      msg.send feeds.join "\n"
