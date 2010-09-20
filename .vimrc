set number
set autoindent
set tabstop=8
set shiftwidth=2
set softtabstop=2
set expandtab

syntax on
set showmode
set cursorline

set nocp
filetype plugin on
set wmnu
set wildmode=longest,list,full
set ignorecase
set smartcase
set incsearch

set foldmethod=indent

command W w
command Q q
command Wq wq
command Wbn w|bn
command Wbp w|bp
command Bn bn
command Bp bp
command Ls ls

au FileType make setlocal noexpandtab
