# vim-textimer

[Efforless](https://www.textimer.app) inspired vim plugin.

## Requirements

 * [`+timer`](https://vim-jp.org/vimdoc-en/various.html#+timers)

## Installation

 * vim-plug
```
Plug 'liquidz/vim-textimer'
```

## Usage

 * Open `*.textimer` file
   * e.g. `$ vim your_project.textimer`
 * Write text something like:
   * `First Task 30`
     * the last word `30` means `30 minutes`
     * vim-textimer will start timer by
       * [CursorHoldI](https://vim-jp.org/vimdoc-en/autocmd.html#CursorHoldI) auto command.
         * depends on [updatetime](https://vim-jp.org/vimdoc-en/options.html#'updatetime') option.
       * `:textimerStart` command.

 * When timer is finished, vim-textimer echos the message.
   * If `g:textimer#finished_command` is defined, specified command will be executed.
     * e.g. To notify on macOS
```
let g:textimer#finished_command = 'osascript'
let g:textimer#finished_exec = '%c -e ''display notification "textimer" with title "%s"'''
```

## License

Copyright (c) 2019 [Iizuka Masashi](http://twitter.com/uochan)

Distributed under the MIT License.
