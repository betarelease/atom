MultiFileOpenView = require './multi-file-open-view'

module.exports =
  multiFileOpenView: null

  activate: (state) ->
    @multiFileOpenView = new MultiFileOpenView(state.multiFileOpenViewState)

  deactivate: ->
    @multiFileOpenView.destroy()

  serialize: ->
    multiFileOpenViewState: @multiFileOpenView.serialize()
