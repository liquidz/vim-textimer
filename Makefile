.PHONY: test

.vim-themis:
	git clone https://github.com/thinca/vim-themis .vim-themis

test: .vim-themis
	./.vim-themis/bin/themis
