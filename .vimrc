filetype off
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()
filetype plugin indent on

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

set list
set listchars=tab:>\ ,trail:>,nbsp:%,conceal:%,precedes:%

"gui options
"   No menubar, no always scrollbars
set guioptions=e
set guifont=Monaco:h12

"make j/k behave soundly.
nnoremap j gj
nnoremap k gk



"shortcuts keys
"man I'm lazy...
map <F2> :NERDTreeToggle<CR>
map <F8> :NERDTree<CR>
map <F3> :set invnumber<CR>
map <F4> :set relativenumber<CR>
map <F5> :VCSBlame<CR>

"more esc keys...because its right next to it anyways
inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>


"dealing with opening files
set wildmenu
set wildmode=longest

"friendlier searching
set ignorecase
set smartcase
set incsearch
"man this gets annoying...
"set hlsearch
set showmatch

"regexin easier
set gdefault    "automagically adds /g on a regex. /g to disable

"mmmm....folding...
set foldmethod=indent
set nofoldenable

"new stuff. 
"set undofile

set background=dark
"colorscheme solarized
"color bluegreen
"color anotherdark
"color wombat
"color mustang
color vividchalk

command W w
command Q q
command Wq wq
command Wbn w|bn
command Wbp w|bp
command Bn bn
command Bp bp
command Ls ls

au FileType make setlocal noexpandtab
au FileType python setlocal noexpandtab
