if exists('g:loaded_effortless')
  finish
endif
let g:loaded_effortless = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

aug effortless
  au!
  au CursorHoldI *.effortless call effortless#check()
aug END

command! EffortlessStart  call effortless#start()
command! EffortlessStop   call effortless#stop()
command! EffortlessPause  call effortless#pause()

let &cpoptions = s:save_cpo
unlet s:save_cpo

