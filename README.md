# vim-effortless

[Efforless](https://www.effortless.app) inspired vim plugin.

## Requirements

 * [`+timer`](https://vim-jp.org/vimdoc-en/various.html#+timers)

## Installation

 * vim-plug
```
Plug 'liquidz/vim-effortless'
```

## Usage

 * Open `*.effortless` file
   * e.g. `$ vim your_project.effortless`
 * Write text something like:
   * `First Task 30`
     * the last word `30` means `30 minutes`
     * vim-effortless will start timer by
       * [CursorHoldI](https://vim-jp.org/vimdoc-en/autocmd.html#CursorHoldI) auto command.
         * depends on [updatetime](https://vim-jp.org/vimdoc-en/options.html#'updatetime') option.
       * `:EffortlessStart` command.

 * When timer is finished, vim-effortless echos the message.
   * If `g:effortless#finished_command` is defined, specified command will be executed.
     * e.g. To notify on macOS
```
let g:effortless#finished_command = 'osascript'
let g:effortless#finished_exec = '%c -e ''display notification "effortless" with title "%s"'''
```

## License

Copyright (c) 2019 [Iizuka Masashi](http://twitter.com/uochan)

Distributed under the MIT License.
