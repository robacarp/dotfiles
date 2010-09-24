filetype off
filetype plugin on
set nocompatible
set modelines=0
set encoding=utf-8
set scrolloff=3

set number
set autoindent
set tabstop=8
set shiftwidth=2
set softtabstop=2
set expandtab

"visual stuff...
syntax on
set showmode
set cursorline
set showcmd
set hidden     "buffers get hidden instead of backgrounded.
set visualbell
set ttyfast    "improves mouse support in x, etc
set ruler      "line/col numbers
set backspace=indent,eol,start   "better backspacing past line start
set laststatus=1   "show status bar with >1 windows only (2 => always)


if version > 730
  set colorcolumn=85
end
set list
set listchars=eol:¬
set listchars=tab:▸\ 

"make j/k behave soundly.
nnoremap j gj
nnoremap k gk
nnoremap <leader>1 :!jekyll<cr><cr>

"more esc keys...because they are right next to it anyways
inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

"again, just because I'm lazy
nnoremap ; :

"dealing with opening files
set wildmenu
set wildmode=list,longest

"friendlier searching
set ignorecase
set smartcase
set incsearch
set hlsearch
set showmatch

"regexin easier
nnoremap / /\v
vnoremap / /\v
set gdefault    "automagically adds /g on a regex. /g to disable

"mmmm....folding...
set foldmethod=indent

"new stuff. 
if version > 730
  set relativenumber
  set undofile
end

command W w
command Q q
command Wq wq
command Wbn w|bn
command Wbp w|bp
command Bn bn
command Bp bp
command Ls ls

au FileType make setlocal noexpandtab
