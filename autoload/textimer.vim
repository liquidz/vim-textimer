let s:save_cpo = &cpoptions
set cpoptions&vim

let g:textimer#started_command = get(g:, 'textimer#started_command', '')
let g:textimer#started_exec = get(g:, 'textimer#started_exec', '%c %s')
let g:textimer#finished_command = get(g:, 'textimer#finished_command', '')
let g:textimer#finished_exec = get(g:, 'textimer#finished_exec', '%c %s')
let g:textimer#popup_height = get(g:, 'textimer#popup_height', 3)
let g:textimer#popup_width = get(g:, 'textimer#popup_width', 30)
let g:textimer#popup_borderchars = get(g:, 'textimer#popup_borderchars', ['-', '|', '-', '|', '+', '+', '+', '+'])
let g:textimer#new_timer_minutes = get(g:, 'textimer#new_timer_minutes', [25, 15, 5])
let g:textimer#done_text = get(g:, 'textimer#done_text', "DONE")

let s:done_text = printf('#%s ', g:textimer#done_text)
let s:timer = textimer#timer#new()

function! s:border() abort
  return repeat('-', g:textimer#popup_width)
endfunction

function! s:construct_command(type, msg) abort
  let exec = (a:type ==# 'finished')
        \ ? g:textimer#finished_exec
        \ : g:textimer#started_exec
  let command = (a:type ==# 'finished')
        \ ? g:textimer#finished_command
        \ : g:textimer#started_command

  let res = substitute(exec, '%c', command, 'g')
  let res = substitute(res, '%s', a:msg, 'g')
  return res
endfunction

function! textimer#id() abort
  let s = reltimestr(reltime())
  let s = split(s, '\.')[0]
  return printf('#tt%s', s)
endfunction

function! s:get_lnum_by_id(bufnr, id) abort
  let lines = getbufline(a:bufnr, 1, '$')
  for i in range(0, len(lines))
    let res = textimer#parse(lines[i])
    if has_key(res, 'id') && res.id ==# a:id
      return i+1
    endif
  endfor

  return -1
endfunction

function! s:generate_line_by_parsed_result(res) abort
  let prefix = (get(a:res, 'done', v:false))
        \ ? s:done_text
        \ : ''
  return printf('%s%s %s %d', prefix, a:res.title, a:res.id, a:res.minutes)
endfunction

function! textimer#done_by_line(bufnr, lnum) abort
  let line = getbufline(a:bufnr, a:lnum)
  if empty(line) | return | endif
  let line = line[0]
  let res = textimer#parse(line)
  if !has_key(res, 'id') | return | endif
  call setbufline(a:bufnr, a:lnum, printf('%s%s', s:done_text, line))

  let res['done'] = v:true
  return res
endfunction

function! textimer#done_by_id(bufnr, id) abort
  let lnum = s:get_lnum_by_id(a:bufnr, a:id)
  if lnum == -1 | return | endif

  call textimer#done_by_line(a:bufnr, lnum)
endfunction

function! textimer#toggle() abort
  let line = getline('.')
  if stridx(line, s:done_text) == 0
    call setline('.', trim(strpart(line, len(s:done_text))))
  else
    let done_task = textimer#done_by_line(bufnr('%'), line('.'))

    if !empty(done_task) && s:timer.is_stoppable() && done_task.id ==# s:timer.context_get('id', '')
      let rest_min = (s:timer.rest_sec / 60)

      if rest_min > 0
        let done_task.minutes -= rest_min
        call setline('.', s:generate_line_by_parsed_result(done_task))
      endif

      call s:timer.stop()
    endif
  endif
endfunction

function! textimer#parse(line, ...) abort
  let line = trim(a:line)
  if stridx(line, s:done_text) == 0
    return textimer#parse(strpart(line, len(s:done_text)), {'done': v:true})
  endif
  if stridx(line, '#') == 0
    return {'comment': v:true}
  endif

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

  let d = copy(get(a:, 1, {}))
  call extend(d, {'title': title, 'minutes': minutes, 'id': id})
  return d
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
    call textimer#done_by_id(ctx.bufnr, ctx.id)
    call popup_close(winid)

    if !empty(g:textimer#finished_command)
      let msg = printf('Finish timer: %s', ctx.title)
      call job_start(s:construct_command('finished', msg))
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
  if !has_key(res, 'minutes')
    return v:false
  endif

  if empty(res.id) || searchpos(res.id, 'bnW') != [0, 0]
    let res.id = textimer#id()
    call setline('.', s:generate_line_by_parsed_result(res))
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

  if !empty(g:textimer#started_command)
    let msg = printf('Start timer: %s', res.title)
    call job_start(s:construct_command('started', msg))
  endif
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
  let line = getline('.')
  let res = textimer#parse(line)

  if get(res, 'done', v:false)
    "" Restart done task again
    let pos = getcurpos()
    call append(line('.'), line)

    let pos[1] += 1
    call setpos('.', pos)

    call textimer#toggle()
    call textimer#start('.')
  else
    "" Restart paused task
    if !s:timer.is_paused()
      echom 'No paused timer'
      return
    endif
    call s:timer.only_start()
  endif
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
  elseif item_name ==# 'Done' || item_name ==# 'Undone'
    call textimer#toggle()
  elseif item_name ==# 'New' && len(item) == 2
    call textimer#new(item[1])
  endif
endfunction

function! textimer#menu() abort
  let line = getline('.')
  let res = textimer#parse(line)

  if get(res, 'comment', v:false) | return | endif

  let is_active = s:timer.is_active()
  let is_paused = s:timer.is_paused()
  let is_stoppable = s:timer.is_stoppable()
  let is_done = get(res, 'done', v:false)
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
    if is_done
      let start_item = printf('Restart "%s" %dm', res.title, res.minutes)
      let done_item = printf('Undone  "%s"', res.title)
    else
      let start_item = printf('Start   "%s" %dm', res.title, res.minutes)
      let done_item = printf('Done    "%s"', res.title)
    endif

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
