# {exec} = require 'child_process'
module.exports = activate: ->
	atom.commands.add 'atom-text-editor', #atom-workspace
	'contextual-preview:toggle': ->
		editor = atom.workspace.getActiveTextEditor()
		#project = atom.project.getPaths()[0]
		#doc = editor.getPath()
		grammar = editor.getGrammar().scopeName
		# https://github.com/execjosh/atom-file-types

		installed = -> atom.packages.resolvePackagePath
		preview = (pkg) -> #atom.workspace
			atom.commands.dispatch atom.views.getView(editor), pkg

		# Context
		if grammar == 'source.gfm' # Markdown
			preview "markdown-preview:toggle" #"#{pkg}:#{cmd}" #pkg.substr 0,pkg.indexOf ':'

		else if grammar == 'text.html.basic' #/html/.test grammar
			if installed pkg = 'atom-html-preview'
			#if exec "apm list -ip | grep -q #{pkg}"
				preview "#{pkg}:toggle"
		else
			if installed pkg = 'source-preview'
				preview "#{pkg}:toggle"
			#else if installed pkg = 'preview-plus'
				#preview "#{pkg}:preview"

		# TODO
		#preview			https://atom.io/packages/preview
		#preview-plus	https://atom.io/packages/preview-plus
		# https://github.com/atom/apm/issues/288
