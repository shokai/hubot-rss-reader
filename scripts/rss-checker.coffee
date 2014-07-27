# Description:
#   RSS Checker Component for Hubot RSS Reader
#
# Author:
#   @shokai

events     = require 'events'
_          = require 'lodash'
request    = require 'request'
FeedParser = require 'feedparser'
async      = require 'async'
debug      = require('debug')('hubot-rss-reader:rss-checker')


module.exports = class RSSChecker extends events.EventEmitter
  constructor: (@robot) ->
    @cache = {}

  fetch: (feed_url_or_opts, callback = ->) ->
    if typeof feed_url_or_opts is 'string'
      feed_url = feed_url_or_opts
      opts = {init: no}
    else
      feed_url = feed_url_or_opts.url
      opts = feed_url_or_opts
    debug "fetch #{feed_url}"
    feedparser = new FeedParser
    req = request feed_url

    req.on 'error', (err) ->
      callback err

    req.on 'response', (res) ->
      stream = this
      if res.statusCode isnt 200
        return callback "statusCode: #{res.statusCode}"
      stream.pipe feedparser

    feedparser.on 'error', (err) ->
      callback err

    entries = []
    feedparser.on 'data', (chunk) =>
      entry =
        url: chunk.link
        title: chunk.title
        summary: chunk.summary
        feed:
          url: feed_url
          title: feedparser.meta.title
        toString: ->
          return "#{process.env.HUBOT_RSS_HEADER} #{@title} - [#{@feed.title}]\n#{@url}\n#{@summary}"
      debug entry
      entries.push entry
      unless @cache[chunk.link]
        @cache[chunk.link] = true
        @emit 'new entry', entry unless opts.init

    feedparser.on 'end', ->
      callback null, entries

  check: (opts = {init: no}, callback = ->) ->
    debug "start checking all feeds"
    feeds = []
    for room, _feeds of (opts.feeds or @robot.brain.get('feeds'))
      feeds = feeds.concat _feeds
    feeds = _.uniq feeds

    interval = 1
    async.eachSeries feeds, (url, next) =>
      do (opts) =>
        setTimeout =>
          opts.url = url
          @fetch opts, (err, entry) =>
            if err
              debug err
              @emit 'error', {error: err, feedUrl: url}
            next()
        , interval
        interval = 5000
    , callback

  getFeeds: (room) ->
    @robot.brain.get('feeds')?[room] or []

  setFeeds: (room, urls) ->
    return unless urls instanceof Array
    feeds = @robot.brain.get('feeds') or {}
    feeds[room] = urls
    @robot.brain.set 'feeds', feeds

  addFeed: (room, url, callback = ->) ->
    feeds = @getFeeds room
    if _.contains feeds, url
      return callback "#{url} is already registered"
    feeds.push url
    @setFeeds room, feeds.sort()
    callback null, "registered #{url}"

  deleteFeed: (room, url, callback = ->) ->
    feeds = @getFeeds room
    unless _.contains feeds, url
      return callback "#{url} is not registered"
    feeds.splice feeds.indexOf(url), 1
    @setFeeds room, feeds
    callback null, "deleted #{url}"
