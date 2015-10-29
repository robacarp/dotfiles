source ~/.dotfiles/.config/nvim/bundle/vim-pathogen/autoload/pathogen.vim
call pathogen#infect('~/.dotfiles/.config/nvim/bundle/{}')

set nobackup
set nowritebackup

" default editing mode
set ts=8 sts=2 sw=2 expandtab ai
syntax on
color mustang

set showmode
set showcmd

"buffers get hidden instead of backgrounded.
set hidden

"shortcuts keys
"man I'm lazy...
map <F2> :NERDTreeToggle<CR>
map <F3> :set invnumber<CR>
map <F4> :set relativenumber<CR>
map <F5> :VCSBlame<CR>
map <F8> :NERDTree<CR>
map <F9> :set invhlsearch<CR> :set invcursorcolumn<CR> :set invcursorline<CR>

set timeoutlen=400
map <Leader>a :NERDTreeFind<CR>

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
set showmatch

"global regexin easier
set gdefault    "automagically adds /g on a regex. /g to disable

"my little pinky isa bit slow coming off that shift key sometimes.
command! W w
command! Q q
command! Wq wq
command! Wbn w|bn
command! Wbp w|bp
command! Bn bn
command! Bp bp
command! Ls ls

" NERDTree enhancements/fixes
"   Nerdtree defaults for window splitting are backwards from vim defaults.
let NERDTreeMapOpenVSplit='i'
let NERDTreeMapOpenSplit='s'
let NERDTreeDirArrows=0
