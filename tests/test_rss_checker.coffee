path = require 'path'
require path.resolve 'tests', 'test_helper'

assert     = require 'assert'
RSSChecker = require path.resolve 'scripts', 'rss-checker'

checker = new RSSChecker {}

describe 'RSSChecker', ->

  it 'sohuld have method "fetch"', ->
    assert.equal typeof checker['fetch'], 'function'

  describe 'method "fetch"', ->

    it 'should emit the event "new entry", and return entries Array', (done) ->

      @timeout 5000

      _entries = []
      checker.on 'new entry', (entry) ->
        _entries.push entry

      checker.fetch 'http://shokai.org/blog/feed', (err, entries) ->
        assert.ok entries instanceof Array
        for entry in entries
          assert typeof entry['url'], 'string'
          assert typeof entry['title'], 'string'
          assert typeof entry['feed'], 'string'
        assert.equal JSON.stringify(entries.sort()), JSON.stringify(_entries.sort())
        done()


    it 'should not emit the event "new entry" if already crawled', (done) ->

      @timeout 5000

      checker.on 'new entry', (entry) ->
        assert.ok false

      checker.fetch 'http://shokai.org/blog/feed', (err, entries) ->
        done()
