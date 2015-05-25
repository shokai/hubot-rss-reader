'use strict'

module.exports = class DummyBot

  constructor: ->
    @brain = {}
    @brain.set = (key, value) =>
      @brain[key] = value
    @brain.get = (key) =>
      @brain[key]
