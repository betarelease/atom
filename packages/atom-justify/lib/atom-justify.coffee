{CompositeDisposable} = require 'atom'
AtomJustifyActions = require './atom-justify-actions'

module.exports = AtomJustify =

    activate: (state) ->
        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        # Register command that toggles this view
        @subscriptions.add atom.commands.add 'atom-workspace', 'atom-justify:createSelection': => @createSelection()
        @subscriptions.add atom.commands.add 'atom-workspace', 'atom-justify:justifyLeft': => @justify("left")
        @subscriptions.add atom.commands.add 'atom-workspace', 'atom-justify:justifyCenter': => @justify("center")
        @subscriptions.add atom.commands.add 'atom-workspace', 'atom-justify:justifyRight': => @justify("right")
        @subscriptions.add atom.commands.add 'atom-workspace', 'atom-justify:justify': => @justify("toggle")

    deactivate: ->
        @subscriptions.dispose()

    createSelection: ->
        AtomJustifyActions.createSelection()

    justify: (position) ->
        AtomJustifyActions.justify(position)
