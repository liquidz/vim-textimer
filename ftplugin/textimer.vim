if exists('g:loaded_textimer')
  finish
endif
let g:loaded_textimer = 1

let s:root = expand("<sfile>:h:h")
let s:script = join([s:root, 'denops', 'textimer', 'mod.ts'], has('win32') ? '\' : '/')

augroup textimer_plugin_internal
  autocmd!
  autocmd User DenopsReady call denops#register('textimer', s:script)
augroup END

"
" let s:save_cpo = &cpoptions
" set cpoptions&vim
"
" setl iskeyword=@,48-57,_,192-255,#
" setl conceallevel=2
"
" aug textimer
"   au!
"   au VimResized *.textimer call textimer#move_popup()
" aug END
"
" command! TextimerStart  call textimer#start_by_current_line()
" command! TextimerStop   call textimer#stop()
" command! TextimerPause  call textimer#pause()
" command! TextimerToggle call textimer#toggle()
" command! TextimerMenu   call textimer#menu()
"
" nnoremap <silent> <Plug>(textimer_start) :<C-u>TextimerStart<CR>
" nnoremap <silent> <Plug>(textimer_menu)  :<C-u>TextimerMenu<CR>
"
" silent! inoremap <buffer> <S-Tab> <C-d>
" if !hasmapto('<Plug>(textimer_menu)')
"   silent! nmap <buffer> <CR><CR> <Plug>(textimer_menu)
" endif
"
" sign define textimer_sign text=>> texthl=Todo
"
" let &cpoptions = s:save_cpo
" unlet s:save_cpo
