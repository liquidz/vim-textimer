let s:save_cpo = &cpoptions
set cpoptions&vim

let g:textimer#finished_command = get(g:, 'textimer#finished_command', '')
let g:textimer#finished_exec = get(g:, 'textimer#finished_exec', '%c %s')
let g:textimer#popup_height = get(g:, 'textimer#popup_height', 3)
let g:textimer#popup_width = get(g:, 'textimer#popup_width', 30)
let g:textimer#popup_borderchars = get(g:, 'textimer#popup_borderchars', ['-', '|', '-', '|', '+', '+', '+', '+'])
let g:textimer#new_timer_minutes = get(g:, 'textimer#new_timer_minutes', [5, 15, 25])

function! s:border() abort
  return repeat('-', g:textimer#popup_width)
endfunction

""" count down timer {{{
let s:timer = {
      \ 'timer': -1,
      \ 'rest_sec': -1,
      \ 'callback': '',
      \ 'context': {},
      \ }

function! s:timer.only_start() abort
  let self.timer = timer_start(1000, {_ -> self.count_down()}, {'repeat': -1})
  return v:true
endfunction

function! s:timer.start(time_sec, callback, ...) abort
  let self.rest_sec = a:time_sec
  let self.callback = a:callback
  let self.context = get(a:, 1, {})
  call self.only_start()
  return v:true
endfunction

function! s:timer.count_down() abort
  if self.rest_sec < 1
    if type(self.callback) == v:t_func
      call self.callback({'type': 'finish', 'context': self.context})
      " reset callback to prevent callbacking in 'stop'
      let self.callback = ''
    endif
    call self.stop()
  else
    let self.rest_sec = self.rest_sec - 1
    if type(self.callback) == v:t_func
      call self.callback({'type': 'count_down', 'rest_sec': self.rest_sec, 'context': self.context})
    endif
  endif
endfunction

function! s:timer.stop() abort
  if !self.is_stoppable() | return v:false | endif
  call timer_stop(self.timer)
  if type(self.callback) == v:t_func
    call self.callback({'type': 'stop', 'context': self.context})
  endif

  let self.timer = -1
  let self.rest_sec = -1
  let self.callback = ''
  let self.context = {}
  return v:true
endfunction

function! s:timer.pause() abort
  if !self.is_active() | return v:false | endif
  call timer_stop(self.timer)
  if type(self.callback) == v:t_func
    call self.callback({'type': 'pause', 'rest_sec': self.rest_sec, 'context': self.context})
  endif

  let self.timer = -1
  return v:true
endfunction

function! s:timer.is_active() abort
  return (self.timer >= 0)
endfunction

function! s:timer.is_paused() abort
  return (self.timer < 0 && self.rest_sec > 0)
endfunction

function! s:timer.is_stoppable() abort
  return (self.is_active() || self.is_paused())
endfunction

function! s:timer.context_get(key, default) abort
  return get(self.context, a:key, a:default)
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

function! s:get_line_info_by_id(id, bufnr) abort
  let lines = getbufline(a:bufnr, 1, '$')
  for i in range(0, len(lines))
    let res = textimer#parse(lines[i])
    if has_key(res, 'id') && res.id ==# a:id
      return [i, lines[i]]
    endif
  endfor

  return [-1, '']
endfunction

function! textimer#done_by_id(id, bufnr) abort
  let [lnum, line] = s:get_line_info_by_id(a:id, a:bufnr)
  if lnum == -1 | return | endif
  call setbufline(a:bufnr, lnum+1, printf('#DONE %s', line))
endfunction

let s:last_sign_id = -1
function! s:place_sign_by_id(id, bufnr) abort
  let [lnum, _] = s:get_line_info_by_id(a:id, a:bufnr)
  if lnum == -1 | return | endif

  if s:last_sign_id > 0
    call sign_unplace('', {'buffer': a:bufnr, 'id': s:last_sign_id})
  endif

  let s:last_sign_id = sign_place(0, '', 'textimer_sign', a:bufnr, {'lnum': lnum+1})
endfunction

function! textimer#toggle() abort
  let line = getline('.')
  if stridx(line, '#') == 0
    call setline('.', trim(line[1:]))
  else
    let res = textimer#parse(line)
    if !empty(res) && s:timer.is_stoppable() && res.id ==# s:timer.context_get('id', '')
      call s:timer.stop()
    endif
    call setline('.', printf('#DONE %s', line))
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

function! s:format_time(sec) abort
  return printf('%02d:%02d', a:sec / 60, a:sec % 60)
endfunction

function! s:timer_callback(event) abort
  let type = get(a:event, 'type', '')
  let sec = get(a:event, 'rest_sec', -1)
  let ctx = get(a:event, 'context', {})
  let winid = get(ctx, 'popup', -1)

  if type ==# 'count_down'
    if winid >= 0 && sec >= 0
      call popup_settext(winid, [ctx.title, s:border(), s:format_time(sec)])
    endif

  elseif type ==# 'stop'
    call popup_close(winid)

  elseif type ==# 'pause'
    call popup_settext(winid, [
          \ ctx.title,
          \ s:border(),
          \ printf('Paused(%s)', s:format_time(sec))
          \ ])

  elseif type ==# 'finish'
    call textimer#done_by_id(ctx.id, ctx.bufnr)
    call popup_close(winid)

    let msg = printf('Finish timer: %s', ctx.title)
    if !empty(g:textimer#finished_command)
      silent call system(s:construct_command(msg))
    endif
  endif
endfunction

function! s:open_popup(title, sec) abort
  let wininfo = getwininfo(win_getid())[0]
  let height = g:textimer#popup_height
  let width = g:textimer#popup_width

  let title_len = len(a:title)
  let height = (title_len > width)
        \ ? height + (title_len / width)
        \ : height
  return popup_create(
        \ [
        \   a:title,
        \   s:border(),
        \   s:format_time(a:sec),
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
endfunction

function! textimer#start(line_number) abort
  let line_number = (type(a:line_number) == v:t_number)
        \ ? a:line_number
        \ : line(a:line_number)
  let line = getline(line_number)
  let res = textimer#parse(line)
  if empty(res) | return v:false | endif

  if empty(res.id) || searchpos(res.id, 'bnW') != [0, 0]
    let res.id = textimer#id()
    call setline('.', printf('%s %s %d', res.title, res.id, res.minutes))
  endif

  let sec = res.minutes * 60
  let context = {
        \ 'id': res.id,
        \ 'title': res.title,
        \ 'bufnr': bufnr('%'),
        \ 'popup': s:open_popup(res.title, sec),
        \ }
  call s:timer.stop()
  call s:timer.start(sec, funcref('s:timer_callback'), context)
endfunction

function! textimer#start_by_current_line() abort
  call textimer#start('.')
endfunction

function! textimer#stop() abort
  if !s:timer.stop()
    echom 'No timer'
  endif
endfunction

function! textimer#pause() abort
  if !s:timer.pause()
    echom 'No timer'
  endif
endfunction

function! textimer#restart() abort
  if !s:timer.is_paused()
    echom 'No paused timer'
    return
  endif

  call s:timer.only_start()
endfunction

function! textimer#new(arg) abort
  let min = str2nr(trim(a:arg, 'm'))
  let line = getline('.')
  call setline('.', printf('%s %d', trim(line), min))
  call textimer#start_by_current_line()
endfunction

function! s:menu_selected(menu_items, _, menu_index) abort
  if a:menu_index < 0 | return | endif
  let item = a:menu_items[a:menu_index-1]
  let item = split(item, '\s\+')
  let item_name = item[0]

  if item_name ==# 'Start'
    call textimer#start_by_current_line()
  elseif item_name ==# 'Stop'
    call textimer#stop()
  elseif item_name ==# 'Pause'
    call textimer#pause()
  elseif item_name ==# 'Restart'
    call textimer#restart()
  elseif item_name ==# 'Done'
    call textimer#toggle()
  elseif item_name ==# 'New' && len(item) == 2
    call textimer#new(item[1])
  endif
endfunction

function! textimer#menu() abort
  let line = getline('.')
  let res = textimer#parse(line)

  let is_active = s:timer.is_active()
  let is_paused = s:timer.is_paused()
  let is_stoppable = s:timer.is_stoppable()
  let ctx_id = s:timer.context_get('id', '')
  let ctx_title = s:timer.context_get('title', '')
  let ctx_rest_sec = s:timer.context_get('rest_sec', -1)
  let ctx_rest_min = ctx_rest_sec / 60

  let items = []
  let stop_item = is_stoppable ? printf('Stop    "%s" %dm', ctx_title, ctx_rest_min) : ''

  if empty(res)
    let items = [stop_item]
    call extend(items, map(copy(g:textimer#new_timer_minutes), {_, v -> printf('New     %dm', v)}))
  else
    let start_item = printf('Start   "%s" %dm', res.title, res.minutes)
    let done_item = printf('Done    "%s"', res.title)

    if is_active && ctx_id ==# res.id
      let pause_item = printf('Pause   "%s" %dm', ctx_title, ctx_rest_min)
      let items = [pause_item, stop_item, done_item]
    elseif is_paused && ctx_id ==# res.id
      let restart_item = printf('Restart "%s" %dm', ctx_title, ctx_rest_min)
      let items = [restart_item, stop_item, done_item]
    else
      let items = [start_item, stop_item, done_item]
    endif
  endif

  call filter(items, {_, v -> !empty(v)})
  call popup_menu(items, {
        \ 'title': 'vim-textimer',
        \ 'borderchars': g:textimer#popup_borderchars,
        \ 'padding': [0, 1, 0, 1],
        \ 'callback': function('s:menu_selected', [items])})
endfunction

function! textimer#move_popup() abort
  let winid = s:timer.context_get('popup', -1)
  if winid < 0 | return | endif

  let wininfo = getwininfo(win_getid())[0]
  let height = g:textimer#popup_height
  let width = g:textimer#popup_width
  call popup_move(winid, {
       \   'line': wininfo['height'] - height,
       \   'col': wininfo['width'] - width - 4,
       \ })
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
