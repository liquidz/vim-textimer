if exists('g:loaded_textimer')
  finish
endif
let g:loaded_textimer = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

aug textimer
  au!
  au CursorHoldI *.textimer call textimer#check_current_line()
  au VimResized *.textimer call textimer#move_popup()
aug END

command! TextimerStart  call textimer#start_by_current_line()
command! TextimerStop   call textimer#stop()
command! TextimerPause  call textimer#pause()
command! TextimerToggle call textimer#toggle()
command! TextimerMenu   call textimer#menu()

nnoremap <silent> <Plug>(textimer_start) :<C-u>TextimerStart<CR>
nnoremap <silent> <Plug>(textimer_menu)  :<C-u>TextimerMenu<CR>

if !hasmapto('<Plug>(textimer_menu)')
  silent! nmap <buffer> <CR><CR> <Plug>(textimer_menu)
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
