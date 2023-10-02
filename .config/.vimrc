source ~/.config/.vim-plugins

" autosave on focus lost
au FocusLost * :wa

set noswapfile

set shell=bash
set nocompatible
set modelines=0
set encoding=utf-8
set scrolloff=3

" basic editor modes
set ts=8 sts=2 sw=2 expandtab ai nu

" visual stuff...
syntax on
set showmode
set showcmd
set hidden     "buffers get hidden instead of backgrounded.
set visualbell
set ttyfast    "improves mouse support in x, etc
set ruler      "line/col numbers
set backspace=indent,eol,start   "better backspacing past line start
set laststatus=2   "show status bar with >1 windows only (2 => always)
set list
set listchars=tab:>\ ,trail:·

"gui options
"   No menubar, no always scrollbars
if has('gui_running')
  set guioptions=e
  set guifont=Fira\ Code:h14
  set macligatures
endif

nmap <leader>- <Plug>VinegarUp
nmap - <Plug>VinegarUp

set timeoutlen=400

"dealing with opening files
set wildmenu
set wildmode=longest

"friendlier searching
set ignorecase
set smartcase
set incsearch
set showmatch
set nohlsearch

" ctrl-p: open the file again and again
let g:ctrlp_switch_buffer = 'et'
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']

"netrw settings
" Hide hidden files by default, credit: https://vi.stackexchange.com/questions/18650/how-to-make-netrw-start-with-dotfiles-hidden/18678#18678
let ghregex='\(^\|\s\s\)\zs\.\S\+'
let g:netrw_list_hide=ghregex

"global regexin easier
set gdefault    "automagically adds /g on a regex. /g to disable

" Keep undo history across sessions, by storing in file.
if has('persistent_undo')
  silent !mkdir ~/.vim/backups > /dev/null 2>&1
  set undodir=~/.vim/backups
  set undofile
endif

"other great options: zmrok, wombat, vividchalk, mustang
set background=dark
color autumn2
let g:colorizer_auto_filetype='css,html,js,scss'


"my little pinky isa bit slow coming off that shift key sometimes.
command! W w
command! Wall wall
command! Bd bd
command! Q q
command! Wq wq

let g:ale_disable_lsp = 1

set wildignore+=*/node_modules/*,*/doc/*,*/coverage/*,*/test/reports/*,*/node-app/*,*/ui-boilerplates/*,*/public/app/*

"tab-important languages
autocmd FileType make setlocal noexpandtab
autocmd FileType python setlocal noexpandtab

"syntax highlighting for the insane
autocmd BufNewFile,BufRead *.pde setf c
autocmd BufNewFile,BufRead *.ino setf c
autocmd BufNewFile,BufRead Rakefile setf ruby
autocmd BufNewFile,BufRead Gemfile setf ruby
autocmd BufNewFile,BufRead Guardfile setf ruby
autocmd BufNewFile,BufRead .vim-plugins setf vim

"set crystal files to handle comment strings properly
autocmd BufNewFile,BufRead *.cr set formatoptions+=roj
let g:crystal_indent_assignment_style = "variable"

let g:scratch_autohide=0
let g:scratch_horizontal=1

nmap <leader>f :let @+ = expand("%") . "\n"<CR>
map <leader>g :GetCurrentBranchLink<CR>
let g:copilot_node_command = '/Users/robert/.asdf/installs/nodejs/16.18.1/bin/node'

" populate and open the quickfix list with an ag search term
function! s:AgSearch(search_term)
  cexpr system('ag ' . a:search_term)
  copen
endfunction

command! -nargs=1 Ag call s:AgSearch(<q-args>)
