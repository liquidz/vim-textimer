""" Time
syn match   elTime '[0-9]\+$'
hi def link elTime Number

""" id
syn match   elId '#el[0-9]\+'
hi def link elId Identifier

""" Comment
syn match   elComment '^#.*'
hi def link elComment Comment

let b:current_syntax = 'effortless'