let s:save_cpo = &cpoptions
set cpoptions&vim

let g:effortless#finished_command = get(g:, 'effortless#finished_command', '')
let g:effortless#finished_exec = get(g:, 'effortless#finished_exec', '%c %s')

function! s:construct_command(msg) abort
  let res = g:effortless#finished_exec
  let res = substitute(res, '%c', g:effortless#finished_command, 'g')
  let res = substitute(res, '%s', a:msg, 'g')
  return res
endfunction

let s:timer = {
    \ 'id': -1,
    \ 'title': '',
    \ 'minutes': -1,
    \ 'rest_sec': -1,
    \ 'paused': v:false,
    \ }

function! s:timer.is_paused() abort
  if self.id < 0 | return v:false | endif
  return self.paused
endfunction

function! s:timer.pause() abort
  if self.id < 0 | return v:false | endif
  call timer_stop(self.id)
  let self.paused = v:true
  return v:true
endfunction

function! s:timer.restart() abort
  if self.id < 0 | return v:false | endif
  let self.id = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})
  echom printf('Restart timer: %s (%d min)', self.title, self.minutes)
  let self.paused = v:false
  return v:true
endfunction

function! s:timer.stop() abort
  if self.id < 0 | return v:false | endif
  call timer_stop(self.id)
  let self.id = -1
  let self.paused = v:false
  return v:true
endfunction

function! s:timer.start(title, minutes) abort
  let sec = a:minutes * 60
  let self.title = a:title
  let self.minutes = a:minutes
  let self.rest_sec = sec
  let self.paused = v:false
  let self.id = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})
  echom printf('Start timer: %s (%d min)', a:title, a:minutes)
endfunction

function! s:timer.count_down() abort
  if self.rest_sec < 1
    call self.stop()
    let msg = printf('Finish timer: %s', self.title)
    echom msg
    if !empty(g:effortless#finished_command)
      silent call system(s:construct_command(msg))
    endif
  else
    let self.rest_sec = self.rest_sec - 1
  endif
endfunction

function! s:parse_current_line() abort
  let line = trim(getline('.'))
  let index = match(line, '\s\+[0-9]\+$')
  if index == -1 | return {} | endif
  return {
       \ 'title': trim(line[0:index]),
       \ 'minutes': str2nr(trim(line[index:])),
       \ }
endfunction

function! effortless#check() abort
  if s:timer.id >= 0 | return | endif
  let res = s:parse_current_line()

  if has_key(res, 'title') && has_key(res, 'minutes')
    call s:timer.start(res.title, res.minutes)
  endif
endfunction

function! effortless#start() abort
  if s:timer.is_paused()
    return s:timer.restart()
  endif
  let res = s:parse_current_line()
  if has_key(res, 'title') && has_key(res, 'minutes')
    call s:timer.stop()
    call s:timer.start(res.title, res.minutes)
  endif
endfunction

function! effortless#stop() abort
  if s:timer.stop()
    echom printf('Stopped timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! effortless#pause() abort
  if s:timer.pause()
    echom printf('Paused timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! effortless#status() abort
  if s:timer.id < 0
    return 'None'
  endif
  let sec = s:timer.rest_sec
  let rest = printf('%02d:%02d', sec / 60, sec % 60)

  if s:timer.paused
    return printf('Paused(%s)', rest)
  endif
  return rest
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
