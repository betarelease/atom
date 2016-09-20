{CompositeDisposable} = require 'atom'

module.exports = Camelify =
  subscriptions: null

  activate: ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'camelify:convert': => @convert()

  deactivate: ->
    @subscriptions.dispose()

  capitalize: ( sWord ) ->
    sWord[0].toUpperCase() + sWord.slice( 1 )

  convert: ->
    if editor = atom.workspace.getActiveTextEditor()
      words = editor.getSelectedText().split(/[ ,.!?/\\;:\-_&@~"'{}()\[\]|`^¨£$%§#]+/).filter( ( n ) -> n != "" )
      firstWord =  words.reverse().pop().toLowerCase()
      camelified = firstWord
      for word in words.reverse()
          camelified += @capitalize word
      editor.insertText camelified
