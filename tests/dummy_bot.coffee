module.exports = class DummyBot

  constructor: ->
    @_brain = {}

    @brain =
      get: (key) =>
        @_brain[key]
      set: (key, value) =>
        @_brain[key] = value
