""" Time
syn match   ttTime '\s\+[0-9]\+$'
hi def link ttTime Number

""" id
syn match   ttId '\s\+#tt[0-9]\+'
hi def link ttId Identifier

""" Comment
syn match   ttComment '^#.*'
hi def link ttComment Comment

let b:current_syntax = 'textimer'
