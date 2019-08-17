let s:save_cpo = &cpoptions
set cpoptions&vim

let g:effortless#finished_command = get(g:, 'effortless#finished_command', '')
let g:effortless#finished_exec = get(g:, 'effortless#finished_exec', '%c %s')
let g:effortless#popup_height = get(g:, 'effortless#popup_height', 3)
let g:effortless#popup_width = get(g:, 'effortless#popup_width', 30)

function! s:border() abort
  return repeat('-', g:effortless#popup_width)
endfunction

" s:timer {{{
let s:timer = {
      \ 'id': '',
      \ 'bufnr': -1,
      \ 'timer': -1,
      \ 'title': '',
      \ 'minutes': -1,
      \ 'rest_sec': -1,
      \ 'paused': v:false,
      \ 'winid': -1,
      \ }

function! s:timer.is_paused() abort
  if self.timer < 0 | return v:false | endif
  return self.paused
endfunction

function! s:timer.rest_time_str() abort
  if self.timer < 0 | return '' | endif
  let sec = s:timer.rest_sec
  return printf('%02d:%02d', sec / 60, sec % 60)
endfunction

function! s:timer.pause() abort
  if self.timer < 0 | return v:false | endif
  call timer_stop(self.timer)
  let self.paused = v:true

  if self.winid >= 0
    call popup_settext(self.winid, [
          \ self.title,
          \ s:border(),
          \ printf('Paused(%s)', self.rest_time_str())
          \ ])
  endif
  return v:true
endfunction

function! s:timer.restart() abort
  if self.timer < 0 | return v:false | endif
  let self.timer = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})
  echom printf('Restart timer: %s (%d min)', self.title, self.minutes)
  let self.paused = v:false
  return v:true
endfunction

function! s:timer.stop() abort
  if self.timer < 0 | return v:false | endif
  call timer_stop(self.timer)
  if self.winid >= 0 | call popup_close(self.winid) | endif
  let self.id = ''
  let self.timer = -1
  let self.paused = v:false
  let self.winid = -1
  return v:true
endfunction

function! s:timer.start(args, bufnr) abort
  let sec = a:args['minutes'] * 60
  let wininfo = getwininfo(win_getid())[0]
  let height = g:effortless#popup_height
  let width = g:effortless#popup_width

  let self.id = a:args['id']
  let self.bufnr = a:bufnr
  let self.title = a:args['title']
  let self.minutes = a:args['minutes']
  let self.rest_sec = sec
  let self.paused = v:false
  let self.timer = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})

  if self.winid >= 0 | call popup_close(self.winid) | endif
  let self.winid = popup_create(
        \ [
        \   a:args['title'],
        \   s:border(),
        \   self.rest_time_str(),
        \ ], {
        \   'line': wininfo['height'] - height,
        \   'col': wininfo['width'] - width,
        \   'minheight': height,
        \   'maxheight': height,
        \   'minwidth': width,
        \   'maxwidth': width,
        \   'border': [],
        \ })
  echom printf('Start timer: %s (%d min)', a:args['title'], a:args['minutes'])
endfunction

function! s:timer.count_down() abort
  if self.rest_sec < 1
    call effortless#done_by_id(self.id, self.bufnr)
    call self.stop()
    let msg = printf('Finish timer: %s', self.title)
    echom msg
    if !empty(g:effortless#finished_command)
      silent call system(s:construct_command(msg))
    endif
  else
    let self.rest_sec = self.rest_sec - 1
    if self.winid >= 0
      call popup_settext(self.winid, [self.title, s:border(), self.rest_time_str()])
    endif
  endif
endfunction
" }}}

function! s:construct_command(msg) abort
  let res = g:effortless#finished_exec
  let res = substitute(res, '%c', g:effortless#finished_command, 'g')
  let res = substitute(res, '%s', a:msg, 'g')
  return res
endfunction

function! effortless#id() abort
  let s = reltimestr(reltime())
  let s = split(s, '\.')[0]
  return printf('#el%s', s)
endfunction

function! effortless#done_by_id(id, bufnr) abort
  let lines = getbufline(a:bufnr, 1, '$')
  for i in range(0, len(lines))
    let res = effortless#parse(lines[i])
    if !has_key(res, 'id') || res.id !=# a:id
      continue
    endif

    call setbufline(a:bufnr, i+1, printf('# %s', lines[i]))
    break
  endfor
endfunction

function! effortless#toggle() abort
  let line = getline('.')
  if stridx(line, '#') == 0
    call setline('.', trim(line[1:]))
  else
    let res = effortless#parse(line)
    if s:timer.timer >= 0 && !empty(res) && res.id ==# s:timer.id
      call s:timer.stop()
    endif
    call setline('.', printf('# %s', line))
  endif
endfunction

function! effortless#parse(line) abort
  let line = trim(a:line)
  if stridx(line, '#') == 0 | return {} | endif
  let index = match(line, '\s\+[0-9]\+$')
  if index == -1 | return {} | endif

  let title = trim(line[0:index])
  let minutes = str2nr(trim(line[index:]))

  let index = match(title, '\s\+#el[0-9]\+$')
  let id = ''
  if index != -1
    let id = trim(title[index:])
    let title = trim(title[0:index])
  endif

  return {'title': title, 'minutes': minutes, 'id': id}
endfunction

function! effortless#start(line, force) abort
  if !a:force && s:timer.timer >= 0
    return v:false
  endif

  let res = effortless#parse(a:line)
  if empty(res) | return v:false | endif

  if empty(res.id)
    let res.id = effortless#id()
    call setline('.', printf('%s %s %d', res.title, res.id, res.minutes))
  endif

  call s:timer.stop()
  call s:timer.start(res, bufnr('%'))
endfunction

function! effortless#check_current_line() abort
  call effortless#start(getline('.'), v:false)
endfunction

function! effortless#check_first_line() abort
  for line in getline(1, '$')
    if stridx(line, '#') == 0 | continue | endif
    call effortless#start(line, v:false)
    break
  endfor
endfunction

function! effortless#start_by_current_line() abort
  call effortless#start(getline('.'), v:true)
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

function! effortless#restart() abort
  if s:timer.restart()
    echom printf('Restart timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! effortless#status() abort
  if s:timer.timer < 0
    return 'None'
  endif
  let sec = s:timer.rest_sec
  let rest = printf('%02d:%02d', sec / 60, sec % 60)

  if s:timer.paused
    return printf('Paused(%s)', rest)
  endif
  return printf('%s(%s)', s:timer.title, rest)
endfunction

function! s:menu_selected(menu_items, x, menu_index) abort
  if a:menu_index < 0 | return | endif
  let item = a:menu_items[a:menu_index-1]
  let item = split(item, '\s\+')[0]

  if item ==# 'Start'
    call effortless#start_by_current_line()
  elseif item ==# 'Stop'
    call effortless#stop()
  elseif item ==# 'Pause'
    call effortless#pause()
  elseif item ==# 'Restart'
    call effortless#restart()
  elseif item ==# 'Done'
    call effortless#toggle()
  endif
endfunction

function! effortless#menu() abort
  let res = effortless#parse(getline('.'))
  if empty(res)
    return
  endif

  let start_item = printf('Start   "%s" %dm', res.title, res.minutes)
  let stop_item = s:timer.timer < 0 ? ''
        \ : printf('Stop    "%s" %dm', s:timer.title, s:timer.rest_sec / 60)
  let done_item = printf('Done    "%s"', res.title)

  let items = []
  if s:timer.timer >= 0 && s:timer.id ==# res.id
    if s:timer.is_paused()
      let restart_item = printf('Restart "%s" %dm', s:timer.title, s:timer.rest_sec / 60)
      let items = [restart_item, stop_item, done_item]
    else
      let pause_item = printf('Pause   "%s" %dm', s:timer.title, s:timer.rest_sec / 60)
      let items = [pause_item, stop_item, done_item]
    endif
  else
    let items = [start_item, stop_item, done_item]
  endif

  call filter(items, {_, v -> !empty(v)})
  call popup_menu(items, {
        \ 'title': 'vim-effortless',
        \ 'callback': function('s:menu_selected', [items])})
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
