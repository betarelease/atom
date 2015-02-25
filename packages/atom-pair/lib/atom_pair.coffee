StartView = require './views/start-view'
InputView = require './views/input-view'
AlertView = require './views/alert-view'

require './pusher/pusher'
require './pusher/pusher-js-client-auth'

randomstring = require 'randomstring'
_ = require 'underscore'
chunkString = require './helpers/chunk-string'

HipChatInvite = require './modules/hipchat_invite'
Marker = require './modules/marker'
GrammarSync = require './modules/grammar_sync'
AtomPairConfig = require './modules/atom_pair_config'

{CompositeDisposable, Range} = require 'atom'

module.exports = AtomPair =

  AtomPairView: null
  modalPanel: null
  subscriptions: null

  config:
    hipchat_token:
      type: 'string'
      description: 'HipChat admin token (optional)'
      default: ''
    hipchat_room_name:
      type: 'string'
      description: 'HipChat room name for sending invitations (optional)'
      default: ''
    pusher_app_key:
      type: 'string'
      description: 'Pusher App Key (sign up at http://pusher.com/signup and change for added security)'
      default: 'd41a439c438a100756f5'
    pusher_app_secret:
      type: 'string'
      description: 'Pusher App Secret'
      default: '4bf35003e819bb138249'

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    @editorListeners = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:start new pairing session': => @startSession()
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:join pairing session': => @joinSession()
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:set configuration keys': => @setConfig()
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:invite over hipchat': => @inviteOverHipChat()
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:custom-paste': => @customPaste()

    atom.commands.add 'atom-workspace', 'AtomPair:hide views': => @hidePanel()
    atom.commands.add '.session-id', 'AtomPair:copyid': => @copyId()

    @colours = require('./helpers/colour-list')
    @friendColours = []
    @timeouts = []
    @events = []
    _.extend(@, HipChatInvite, Marker, GrammarSync, AtomPairConfig)

  customPaste: ->
    text = atom.clipboard.read()
    if text.length > 800
      chunks = chunkString(text, 800)
      _.each chunks, (chunk, index) =>
        setTimeout(( =>
          atom.clipboard.write(chunk)
          @editor.pasteText()
          if index is (chunks.length - 1) then atom.clipboard.write(text)
        ), 180 * index)
    else
      @editor.pasteText()

  disconnect: ->
    @pusher.disconnect()
    @editorListeners.dispose()
    _.each @friendColours, (colour) => @clearMarkers(colour)
    atom.views.getView(@editor).removeAttribute('id')
    @hidePanel()

  copyId: ->
    atom.clipboard.write(@sessionId)

  hidePanel: ->
    _.each atom.workspace.getModalPanels(), (panel) -> panel.hide()

  joinSession: ->

    if @markerColour
      alreadyPairing = new AlertView "It looks like you are already in a pairing session. Please open a new window (cmd+shift+N) to start/join a new one."
      atom.workspace.addModalPanel(item: alreadyPairing, visible: true)
      return

    @joinView = new InputView("Enter the session ID here:")
    @joinPanel = atom.workspace.addModalPanel(item: @joinView, visible: true)
    @joinView.miniEditor.focus()

    @joinView.on 'core:confirm', =>
      @sessionId = @joinView.miniEditor.getText()
      keys = @sessionId.split("-")
      [@app_key, @app_secret] = [keys[0], keys[1]]
      @joinPanel.hide()

      atom.workspace.open().then => @pairingSetup() #starts a new tab to join pairing session

  startSession: ->
    @getKeysFromConfig()

    if @missingPusherKeys()
      alertView = new AlertView "Please set your Pusher keys."
      atom.workspace.addModalPanel(item: alertView, visible: true)
    else
      @generateSessionId()
      @startView = new StartView(@sessionId)
      @startPanel = atom.workspace.addModalPanel(item: @startView, visible: true)
      @startView.focus()
      @markerColour = @colours[0]
      @pairingSetup()

  generateSessionId: ->
    @sessionId = "#{@app_key}-#{@app_secret}-#{randomstring.generate(11)}"

  pairingSetup: ->
    @editor = atom.workspace.getActiveEditor()
    if !@editor then return atom.workspace.open().then => @pairingSetup()
    atom.views.getView(@editor).setAttribute('id', 'AtomPair')
    @connectToPusher()
    @synchronizeColours()
    @subscriptions.add atom.commands.add 'atom-workspace', 'AtomPair:disconnect': => @disconnect()

  connectToPusher: ->
    @pusher = new Pusher @app_key,
      authTransport: 'client'
      clientAuth:
        key: @app_key
        secret: @app_secret
        user_id: @markerColour || "blank"

    @pairingChannel = @pusher.subscribe("presence-session-#{@sessionId}")

  synchronizeColours: ->
    @pairingChannel.bind 'pusher:subscription_succeeded', (members) =>
      @membersCount = members.count
      return @resubscribe() unless @markerColour
      colours = Object.keys(members.members)
      @friendColours = _.without(colours, @markerColour)
      _.each(@friendColours, (colour) => @addMarker 0, colour)
      @startPairing()

  resubscribe: ->
    @pairingChannel.unsubscribe()
    @markerColour = @colours[@membersCount - 1]
    @connectToPusher()
    @synchronizeColours()

  startPairing: ->

    @triggerPush = true
    buffer = @buffer = @editor.buffer

    # listening for Pusher events

    @pairingChannel.bind 'pusher:member_added', (member) =>
      noticeView = new AlertView "Your pair buddy has joined the session."
      atom.workspace.addModalPanel(item: noticeView, visible: true)
      @sendGrammar()
      @shareCurrentFile()
      @friendColours.push(member.id)
      @addMarker 0, member.id

    @pairingChannel.bind 'client-grammar-sync', (syntax) =>
      grammar = atom.grammars.grammarForScopeName(syntax)
      @editor.setGrammar(grammar)

    @pairingChannel.bind 'client-share-whole-file', (file) =>
      @triggerPush = false
      buffer.setText(file)
      @triggerPush = true

    @pairingChannel.bind 'client-share-partial-file', (chunk) =>
      @triggerPush = false
      buffer.append(chunk)
      @triggerPush = true

    @pairingChannel.bind 'client-change', (events) =>
      _.each events, (event) =>
        @changeBuffer(event) if event.eventType is 'buffer-change'
        if event.eventType is 'buffer-selection'
          @updateCollaboratorMarker(event)

    @pairingChannel.bind 'pusher:member_removed', (member) =>
      @clearMarkers(member.id)
      disconnectView = new AlertView "Your pair buddy has left the session."
      atom.workspace.addModalPanel(item: disconnectView, visible: true)

    @triggerEventQueue()

    # listening for buffer events
    @editorListeners.add @listenToBufferChanges()
    @editorListeners.add @syncSelectionRange()
    @editorListeners.add @syncGrammars()

    # listening for its own demise
    @listenForDestruction()

  listenForDestruction: ->
    @editorListeners.add @buffer.onDidDestroy => @disconnect()
    @editorListeners.add @editor.onDidDestroy => @disconnect()

  listenToBufferChanges: ->
    @buffer.onDidChange (event) =>
      return unless @triggerPush
      if !(event.newText is "\n") and (event.newText.length is 0)
        changeType = 'deletion'
        event = {oldRange: event.oldRange}
      else if event.oldRange.containsRange(event.newRange)
        changeType = 'substitution'
        event = {oldRange: event.oldRange, newRange: event.newRange, newText: event.newText}
      else
        changeType = 'insertion'
        event  = {newRange: event.newRange, newText: event.newText}

      event = {changeType: changeType, event: event, colour: @markerColour, eventType: 'buffer-change'}
      @events.push(event)

  changeBuffer: (data) ->
    if data.event.newRange then newRange = Range.fromObject(data.event.newRange)
    if data.event.oldRange then oldRange = Range.fromObject(data.event.oldRange)
    if data.event.newText then newText = data.event.newText

    @triggerPush = false

    @clearMarkers(data.colour)

    switch data.changeType
      when 'deletion'
        @buffer.delete oldRange
        actionArea = oldRange.start
      when 'substitution'
        @buffer.setTextInRange oldRange, newText
        actionArea = oldRange.start
      else
        @buffer.insert newRange.start, newText
        actionArea = newRange.start

    @editor.scrollToBufferPosition(actionArea)
    @addMarker(actionArea.toArray()[0], data.colour)

    @triggerPush = true

  syncSelectionRange: ->
    @editor.onDidChangeSelectionRange (event) =>
      rows = event.newBufferRange.getRows()
      return unless rows.length > 1
      @events.push {eventType: 'buffer-selection', colour: @markerColour, rows: rows}

  triggerEventQueue: ->
    @eventInterval = setInterval(=>
      if @events.length > 0
        @pairingChannel.trigger 'client-change', @events
        @events = []
    , 120)

  shareCurrentFile: ->
    currentFile = @buffer.getText()
    return if currentFile.length is 0

    if currentFile.length < 950
      @pairingChannel.trigger 'client-share-whole-file', currentFile
    else
      chunks = chunkString(currentFile, 950)
      _.each chunks, (chunk, index) =>
        setTimeout(( => @pairingChannel.trigger 'client-share-partial-file', chunk), 180 * index)