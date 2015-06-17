module.exports =
class MultiFileOpenView
  constructor: (serializeState) ->
    atom.commands.add 'atom-workspace', 'multi-file-open:open': => @open()

  open: (contents) ->
    treeView = document.getElementsByClassName "tree-view-scroller"
    return if not treeView.length

    view = atom.workspaceView
    view.open span.dataset.path for span in treeView[0].querySelectorAll ".selected>span"
