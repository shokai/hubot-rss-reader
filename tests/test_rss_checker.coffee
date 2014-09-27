path = require 'path'
require path.resolve 'tests', 'test_helper'

assert     = require 'assert'
RSSChecker = require path.resolve 'libs', 'rss-checker'

checker = new RSSChecker {}

describe 'RSSChecker', ->

  it 'sohuld have method "fetch"', ->
    assert.equal typeof checker['fetch'], 'function'

  describe 'method "fetch"', ->

    it 'should emit the event "new entry", and callback entries Array', (done) ->

      @timeout 5000

      checker = new RSSChecker {}
      _entries = []
      checker.on 'new entry', (entry) ->
        _entries.push entry

      checker.fetch 'http://shokai.org/blog/feed', (err, entries) ->
        assert.ok entries instanceof Array
        for entry in entries
          assert.equal typeof entry.url, 'string', '"url" property not exists'
          assert.equal typeof entry.title, 'string', '"title" property not exists'
          assert.equal typeof entry.summary, 'string', '"summary" property not exists'
          assert.equal typeof entry.feed?.url, 'string', '"feed.url" property not exists'
          assert.equal typeof entry.feed?.title, 'string', '"feed.title" property not exists'
        assert.equal JSON.stringify(entries.sort()), JSON.stringify(_entries.sort())
        done()


    it 'should not emit the event "new entry" if already crawled', (done) ->

      @timeout 5000

      checker.on 'new entry', (entry) ->
        assert.ok false

      checker.fetch 'http://shokai.org/blog/feed', (err, entries) ->
        done()


  it 'should have method "check"', ->
    assert.equal typeof checker['check'], 'function'

  describe 'methods "check"', ->

    it 'should not emit the event "new entry" if {init: yes} option', (done) ->

      @timeout 15000

      checker = new RSSChecker {}
      checker.on 'new entry', (entry) ->
        assert.ok false, 'detect new entry'

      checker.check {
        init: yes
        feeds: [
          'http://shokai.org/blog/feed'
          'https://github.com/shokai.atom'
        ]
      }, done


    it 'should emit the event "new entry" if {init: no} option', (done) ->

      @timeout 15000

      checker = new RSSChecker {}
      entries_shokai_org = []
      entries_githbu_com = []
      checker.on 'new entry', (entry) ->
        switch
          when /shokai.org/.test entry.url
            entries_shokai_org.push entry
          when /github.com/.test entry.url
            entries_githbu_com.push entry

      checker.check {
        init: no
        feeds: [
          'http://shokai.org/blog/feed'
          'https://github.com/shokai.atom'
        ]
      }, ->
        assert.ok(entries_githbu_com.length > 0, 'detect github.com new entries')
        assert.ok(entries_shokai_org.length > 0, 'detect shokai.org new entries')
        done()
