path = require 'path'
require path.resolve 'tests', 'test_helper'

assert     = require 'assert'
RSSChecker = require path.resolve 'libs', 'rss-checker'
Promise    = require 'bluebird'
DummyBot   = require './dummy_bot'

checker = new RSSChecker new DummyBot

describe 'RSSChecker', ->

  it 'sohuld have method "fetch"', ->
    assert.equal typeof checker['fetch'], 'function'

  describe 'method "fetch"', ->

    it 'should emit the event "new entry", and callback entries Array', ->

      @timeout 5000

      checker = new RSSChecker new DummyBot
      _entries = []
      checker.on 'new entry', (entry) ->
        _entries.push entry

      checker.fetch 'http://shokai.org/blog/feed'
      .then (entries) ->
        assert.ok entries instanceof Array
        for entry in entries
          assert.equal typeof entry.url, 'string', '"url" property not exists'
          assert.equal typeof entry.title, 'string', '"title" property not exists'
          assert.equal typeof entry.summary, 'string', '"summary" property not exists'
          assert.equal typeof entry.feed?.url, 'string', '"feed.url" property not exists'
          assert.equal typeof entry.feed?.title, 'string', '"feed.title" property not exists'
        assert.equal JSON.stringify(entries.sort()), JSON.stringify(_entries.sort())




    it 'should not emit the event "new entry" if already crawled', ->

      @timeout 5000

      checker.on 'new entry', (entry) ->
        assert.ok false

      checker.fetch 'http://shokai.org/blog/feed'
      .then (entries) ->
        new Promise (resolve, reject) ->
          setTimeout ->
            resolve entries
          , 500



  it 'should have method "check"', ->
    assert.equal typeof checker['check'], 'function'

  describe 'methods "check"', ->

    it 'should emit the event "new entry"', ->

      @timeout 15000

      checker = new RSSChecker new DummyBot
      checker.on 'new entry', (entry) ->
        assert.ok true, 'detect new entry'

      checker.check
        init: yes
        feeds: [
          'http://shokai.org/blog/feed'
          'https://github.com/shokai.atom'
        ]
