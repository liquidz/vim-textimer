let s:save_cpo = &cpoptions
set cpoptions&vim

let g:textimer#finished_command = get(g:, 'textimer#finished_command', '')
let g:textimer#finished_exec = get(g:, 'textimer#finished_exec', '%c %s')
let g:textimer#popup_height = get(g:, 'textimer#popup_height', 3)
let g:textimer#popup_width = get(g:, 'textimer#popup_width', 30)
let g:textimer#popup_borderchars = get(g:, 'textimer#popup_borderchars', ['-', '|', '-', '|', '+', '+', '+', '+'])

function! s:border() abort
  return repeat('-', g:textimer#popup_width)
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
  let height = g:textimer#popup_height
  let width = g:textimer#popup_width

  let self.id = a:args['id']
  let self.bufnr = a:bufnr
  let self.title = a:args['title']
  let self.minutes = a:args['minutes']
  let self.rest_sec = sec
  let self.paused = v:false
  let self.timer = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})

  if self.winid >= 0 | call popup_close(self.winid) | endif

  let title_len = len(a:args['title'])
  let height = (title_len > width)
        \ ? height + (title_len / width)
        \ : height
  let self.winid = popup_create(
        \ [
        \   a:args['title'],
        \   s:border(),
        \   self.rest_time_str(),
        \ ], {
        \   'line': wininfo['height'] - height,
        \   'col': wininfo['width'] - width - 4,
        \   'minheight': height,
        \   'maxheight': height,
        \   'minwidth': width,
        \   'maxwidth': width,
        \   'border': [],
        \   'borderchars': g:textimer#popup_borderchars,
        \   'padding': [0, 1, 0, 1],
        \ })
  echom printf('Start timer: %s (%d min)', a:args['title'], a:args['minutes'])
endfunction

function! s:timer.count_down() abort
  if self.rest_sec < 1
    call textimer#done_by_id(self.id, self.bufnr)
    call self.stop()
    let msg = printf('Finish timer: %s', self.title)
    echom msg
    if !empty(g:textimer#finished_command)
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
  let res = g:textimer#finished_exec
  let res = substitute(res, '%c', g:textimer#finished_command, 'g')
  let res = substitute(res, '%s', a:msg, 'g')
  return res
endfunction

function! textimer#id() abort
  let s = reltimestr(reltime())
  let s = split(s, '\.')[0]
  return printf('#tt%s', s)
endfunction

function! textimer#done_by_id(id, bufnr) abort
  let lines = getbufline(a:bufnr, 1, '$')
  for i in range(0, len(lines))
    let res = textimer#parse(lines[i])
    if !has_key(res, 'id') || res.id !=# a:id
      continue
    endif

    call setbufline(a:bufnr, i+1, printf('# %s', lines[i]))
    break
  endfor
endfunction

function! textimer#toggle() abort
  let line = getline('.')
  if stridx(line, '#') == 0
    call setline('.', trim(line[1:]))
  else
    let res = textimer#parse(line)
    if s:timer.timer >= 0 && !empty(res) && res.id ==# s:timer.id
      call s:timer.stop()
    endif
    call setline('.', printf('# %s', line))
  endif
endfunction

function! textimer#parse(line) abort
  let line = trim(a:line)
  if stridx(line, '#') == 0 | return {} | endif
  let index = match(line, '\s\+[0-9]\+$')
  if index == -1 | return {} | endif

  let title = trim(line[0:index])
  let minutes = str2nr(trim(line[index:]))

  let index = match(title, '\s\+#tt[0-9]\+$')
  let id = ''
  if index != -1
    let id = trim(title[index:])
    let title = trim(title[0:index])
  endif

  return {'title': title, 'minutes': minutes, 'id': id}
endfunction

function! textimer#start(line, force) abort
  if !a:force && s:timer.timer >= 0
    return v:false
  endif

  let res = textimer#parse(a:line)
  if empty(res) | return v:false | endif

  if empty(res.id)
    let res.id = textimer#id()
    call setline('.', printf('%s %s %d', res.title, res.id, res.minutes))
  endif

  call s:timer.stop()
  call s:timer.start(res, bufnr('%'))
endfunction

function! textimer#check_current_line() abort
  call textimer#start(getline('.'), v:false)
endfunction

function! textimer#check_first_line() abort
  for line in getline(1, '$')
    if stridx(line, '#') == 0 | continue | endif
    call textimer#start(line, v:false)
    break
  endfor
endfunction

function! textimer#start_by_current_line() abort
  call textimer#start(getline('.'), v:true)
endfunction

function! textimer#stop() abort
  if s:timer.stop()
    echom printf('Stopped timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! textimer#pause() abort
  if s:timer.pause()
    echom printf('Paused timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! textimer#restart() abort
  if s:timer.restart()
    echom printf('Restart timer: %s', s:timer.title)
    return
  endif
  echom 'No timer'
endfunction

function! textimer#status() abort
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
    call textimer#start_by_current_line()
  elseif item ==# 'Stop'
    call textimer#stop()
  elseif item ==# 'Pause'
    call textimer#pause()
  elseif item ==# 'Restart'
    call textimer#restart()
  elseif item ==# 'Done'
    call textimer#toggle()
  endif
endfunction

function! textimer#menu() abort
  let res = textimer#parse(getline('.'))
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
        \ 'title': 'vim-textimer',
        \ 'borderchars': g:textimer#popup_borderchars,
        \ 'padding': [0, 1, 0, 1],
        \ 'callback': function('s:menu_selected', [items])})
endfunction

function! textimer#move_popup() abort
  if s:timer.winid < 0 | return | endif
  let wininfo = getwininfo(win_getid())[0]

  let height = g:textimer#popup_height
  let width = g:textimer#popup_width
  call popup_move(s:timer.winid, {
       \   'line': wininfo['height'] - height,
       \   'col': wininfo['width'] - width - 4,
       \ })
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
