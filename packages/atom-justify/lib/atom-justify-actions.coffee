{Range, CompositeDisposable} = require 'atom'
module.exports =
class AtomJustifyActions
    @position = ""
    @createSelection: () ->
        editor = atom.workspace.getActiveEditor()
        startRow = endRow = startCol = endCol = -1
        cursors = editor.getCursors()

        if cursors.length == 2
            for cursor in cursors
                row = cursor.getBufferRow()
                col = cursor.getBufferColumn()

                startRow = if startRow == -1 || startRow > row && row <= endRow then row else startRow
                endRow   = if endRow == -1 || endRow < row && row >= startRow then row else endRow
                startCol = if startCol == -1 || startCol > col && col <= endCol then col else startCol
                endCol   = if endCol == -1 || endCol < col && col >= startCol then col else endCol

            ranges = []
            endRow++
            for r in [startRow...endRow]
                range = new Range [r, startCol], [r, endCol]
                if editor.getTextInBufferRange(range) != ""
                    ranges.push(range)

            editor.setSelectedBufferRanges (ranges)

        return

    @justify: (position="toggle") ->
        if position == "toggle"
            if @position == "" || @position == "right"
                position = "left"
            else if @position == "left"
                position = "center"
            else
                position = "right"

        @position = position

        editor = atom.workspace.getActiveEditor()
        ranges = editor.getSelectedBufferRanges()
        if ranges.length > 0
            max = ranges[0].end.column - ranges[0].start.column
            for range in ranges
                text = editor.getTextInRange(range).trim()
                l = text.length
                diff = max - l
                if diff > 0
                    if @position == "center"
                        f = Math.floor(diff/2)
                        e = diff - f
                        text = Array(++f).join(" ") + text + Array(++e).join(" ")
                    else
                        blanks = Array(++diff).join(" ")
                        text = if position == "left" then text + blanks else blanks + text

                    editor.setTextInBufferRange(range, text)

        return
