if exists('g:loaded_effortless')
  finish
endif
let g:loaded_effortless = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

aug effortless
  au!
  au CursorHoldI *.effortless call effortless#check_current_line()
aug END

command! EffortlessStart  call effortless#start_by_current_line()
command! EffortlessStop   call effortless#stop()
command! EffortlessPause  call effortless#pause()
command! EffortlessToggle call effortless#toggle()

nnoremap <silent> <Plug>(effortless_start) :<C-u>EffortlessStart<CR>

if !hasmapto('<Plug>(effortless_start)')
  silent! nmap <buffer> <CR><CR> <Plug>(effortless_start)
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

