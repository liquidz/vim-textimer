let s:suite  = themis#suite('effortless')
let s:assert = themis#helper('assert')

function! s:suite.id_test() abort
  let id = effortless#id()
  call s:assert.true(!empty(id))
  call s:assert.equals(stridx(id, '#'), 0)
endfunction

function! s:suite.parse_test() abort
  call s:assert.equals(effortless#parse('foo'), {})
  call s:assert.equals(effortless#parse('foo 10'), {'title': 'foo', 'minutes': 10, 'id': ''})
  call s:assert.equals(effortless#parse('foo10'), {})
  call s:assert.equals(effortless#parse('foo1 0'), {'title': 'foo1', 'minutes': 0, 'id': ''})

  let id = effortless#id()
  call s:assert.equals(effortless#parse(printf('foo %s 10', id)),
        \ {'title': 'foo', 'minutes': 10, 'id': id})
endfunction
