let s:save_cpo = &cpoptions
set cpoptions&vim

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

function! textimer#timer#new() abort
	return deepcopy(s:timer)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
