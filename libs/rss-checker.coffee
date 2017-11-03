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
Entities   = require('html-entities').XmlEntities
entities   = new Entities
async      = require 'async'
debug      = require('debug')('hubot-rss-reader:rss-checker')
cheerio    = require 'cheerio'
Promise    = require 'bluebird'
IrcColor   = require 'irc-colors'

charsetConvertStream = require './charset-convert-stream'
Entries = require './entries'

module.exports = class RSSChecker extends events.EventEmitter
  constructor: (@robot) ->
    @entries = new Entries @robot

  cleanup_summary = (html = '') ->
    summary = do (html) ->
      try
        $ = cheerio.load html
        if process.env.HUBOT_RSS_PRINTIMAGE is 'true'
          if img = $('img').attr('src')
            return img + '\n' + $.root().text()
        return $.root().text()
      catch
        return html
    lines = summary.split /[\r\n]/
    lines = lines.map (line) -> if /^\s+$/.test line then '' else line
    summary = lines.join '\n'
    return summary.replace(/\n\n\n+/g, '\n\n')

  fetch: (args) ->
    new Promise (resolve, reject) =>
      default_args =
        url: null
        room: null

      if typeof args is 'string'
        args = {url: args}
      for k,v of default_args
        unless args.hasOwnProperty k
          args[k] = v
      debug "fetch #{args.url}"
      debug args
      feedparser = new FeedParser {feedurl: args.url}
      req = request
        uri: args.url
        timeout: 10000
        encoding: null
        headers:
          'User-Agent': process.env.HUBOT_RSS_USERAGENT

      req.on 'error', (err) ->
        reject err

      req.on 'response', (res) ->
        if res.statusCode isnt 200
          return reject "statusCode: #{res.statusCode}"
        this
          .pipe charsetConvertStream()
          .pipe feedparser

      feedparser.on 'error', (err) ->
        reject err

      entries = []
      feedparser.on 'data', (chunk) =>
        entry =
          url: chunk.link
          title: entities.decode(chunk.title or '')
          summary: cleanup_summary entities.decode(chunk.summary or chunk.description or '')
          feed:
            url: args.url
            title: entities.decode(feedparser.meta.title or '')
          toString: ->
            if process.env.HUBOT_RSS_IRCCOLORS is "true"
              s = "#{IrcColor.pink(process.env.HUBOT_RSS_HEADER)} #{@title} #{IrcColor.purple('- ['+@feed.title+']')}\n#{IrcColor.lightgrey.underline(@url)}"
            else
              s = "#{process.env.HUBOT_RSS_HEADER} #{@title} - [#{@feed.title}]\n#{@url}"

            if process.env.HUBOT_RSS_PRINTSUMMARY is "true" and @summary?.length > 0
              s += "\n#{@summary}"
            return s
          args: args

        debug entry
        entries.push entry
        unless @entries.include entry.url
          @entries.add entry.url
          @emit 'new entry', entry

      feedparser.on 'end', ->
        resolve entries

  check: (opts = {}) ->
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
      if _.includes feeds, url
        return reject "#{url} is already registered"
      feeds.push url
      @setFeeds room, feeds.sort()
      resolve "registered #{url}"

  deleteFeed: (room, url) ->
    new Promise (resolve, reject) =>
      feeds = @getFeeds room
      unless _.includes feeds, url
        return reject "#{url} is not registered"
      feeds.splice feeds.indexOf(url), 1
      @setFeeds room, feeds
      resolve "deleted #{url}"

  deleteRoom: (name) ->
    new Promise (resolve, reject) =>
      rooms = @getAllFeeds() or {}
      unless rooms.hasOwnProperty name
        return reject "room ##{name} is not exists"
      delete rooms[name]
      @robot.brain.set 'feeds', rooms
      resolve "deleted room ##{name}"
