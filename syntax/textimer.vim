""" Time
syn match   ttTime '\s\+[0-9]\+$'
hi def link ttTime Number

""" Id
syn match   ttId '\s\+#tt[0-9]\+' conceal
hi def link ttId Identifier

""" Todo
syn keyword ttTodo         contained TODO FIXME XXX BUG
syn cluster ttCommentGroup contains=ttTodo
hi def link ttTodo         Todo

""" Comment
syn match   ttComment '^\s*#.*' contains=ttId,@ttCommentGroup
hi def link ttComment Comment

let b:current_syntax = 'textimer'
