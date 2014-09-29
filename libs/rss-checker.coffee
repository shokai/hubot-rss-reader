# Description:
#   RSS Checker Component for Hubot RSS Reader
#
# Author:
#   @shokai

'use strict'

events     = require 'events'
_          = require 'lodash'
request    = require 'request'
FeedParser = require 'feedparser'
async      = require 'async'
debug      = require('debug')('hubot-rss-reader:rss-checker')
cheerio    = require 'cheerio'
Promise    = require 'bluebird'

module.exports = class RSSChecker extends events.EventEmitter
  constructor: (@robot) ->
    @cache = {}

  cleanup_summary = (html) ->
    summary = do (html) ->
      try
        $ = cheerio.load html
        if img = $('img').attr('src')
          return img + '\n' + $.root().text()
        return $.root().text()
      catch
        return html
    lines = summary.split /[\r\n]/
    lines = lines.map (line) -> if /^\s+$/.test line then '' else line
    summary = lines.join '\n'
    return summary.replace(/\n\n\n+/g, '\n\n')

  fetch: (feed_url_or_opts) ->
    new Promise (resolve, reject) =>
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
        reject err

      req.on 'response', (res) ->
        stream = this
        if res.statusCode isnt 200
          return reject "statusCode: #{res.statusCode}"
        stream.pipe feedparser

      feedparser.on 'error', (err) ->
        reject err

      entries = []
      feedparser.on 'data', (chunk) =>
        entry =
          url: chunk.link
          title: chunk.title
          summary: cleanup_summary(chunk.summary or chunk.description)
          feed:
            url: feed_url
            title: feedparser.meta.title
          toString: ->
            s = "#{process.env.HUBOT_RSS_HEADER} #{@title} - [#{@feed.title}]\n#{@url}"
            s += "\n#{@summary}" if @summary?.length > 0
            return s

        debug entry
        entries.push entry
        unless @cache[chunk.link]
          @cache[chunk.link] = true
          @emit 'new entry', entry unless opts.init

      feedparser.on 'end', ->
        resolve entries

  check: (opts = {init: no}) ->
    new Promise (resolve) =>
      debug "start checking all feeds"
      feeds = []
      for room, _feeds of (opts.feeds or @robot.brain.get('feeds'))
        feeds = feeds.concat _feeds
      resolve _.uniq feeds
    .then (feeds) =>
      interval = 1
      Promise.each feeds, (url) =>
        new Promise (resolve) ->
          setTimeout =>
            resolve url
          , interval
          interval = 5000
        .then (url) =>
          do (opts) =>
            opts.url = url
            @fetch opts
        .catch (err) =>
          debug err
          @emit 'error', {error: err, feed: {url: url}}
    .then (feeds) ->
      new Promise (resolve) ->
        debug "check done (#{feeds?.length or 0} feeds)"
        resolve feeds

  getAllFeeds: ->
    @robot.brain.get 'feeds'

  getFeeds: (room) ->
    @getAllFeeds()?[room] or []

  setFeeds: (room, urls) ->
    return unless urls instanceof Array
    feeds = @robot.brain.get('feeds') or {}
    feeds[room] = urls
    @robot.brain.set 'feeds', feeds

  addFeed: (room, url) ->
    new Promise (resolve, reject) =>
      feeds = @getFeeds room
      if _.contains feeds, url
        return reject "#{url} is already registered"
      feeds.push url
      @setFeeds room, feeds.sort()
      resolve "registered #{url}"

  deleteFeed: (room, url) ->
    new Promise (resolve, reject) =>
      feeds = @getFeeds room
      unless _.contains feeds, url
        return reject "#{url} is not registered"
      feeds.splice feeds.indexOf(url), 1
      @setFeeds room, feeds
      resolve "deleted #{url}"
