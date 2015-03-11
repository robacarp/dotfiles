filetype off
source ~/.dotfiles/.vim/bundle/vim-pathogen/autoload/pathogen.vim
call pathogen#infect('~/.dotfiles/.vim/bundle/{}')
filetype plugin indent on

set shell=bash
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
" set cursorline " seems to interfere with the ruby syntaxthighlighting
set showcmd
set hidden     "buffers get hidden instead of backgrounded.
set visualbell
set ttyfast    "improves mouse support in x, etc
set ruler      "line/col numbers
set backspace=indent,eol,start   "better backspacing past line start
set laststatus=1   "show status bar with >1 windows only (2 => always)

set list
set listchars=tab:>\ ,trail:>

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
map <F3> :set invnumber<CR>
map <F4> :set relativenumber<CR>
map <F5> :VCSBlame<CR>
map <F8> :NERDTree<CR>
map <F9> :set invhlsearch<CR> :set invcursorcolumn<CR> :set invcursorline<CR>
map <F12> :JSHint<CR>

"more esc keys...because its right next to it anyways
inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

"Switch between tabs rather intuitively
nnoremap th :tabprev<CR>
nnoremap tl :tabnext<CR>

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

"mmmm....folding...
set foldmethod=indent
set nofoldenable

set undofile

set background=dark
"colorscheme solarized
"color bluegreen
"color anotherdark
" color wombat
color mustang
" color vividchalk

"my little pinky isa bit slow coming off that shift key sometimes.
command W w
command Q q
command Wq wq
command Wbn w|bn
command Wbp w|bp
command Bn bn
command Bp bp
command Ls ls

" NERDTree enhancements/fixes
"   Nerdtree defaults for window splitting are backwards from vim defaults.
let NERDTreeMapOpenVSplit='i'
let NERDTreeMapOpenSplit='s'
let NERDTreeDirArrows=0

set wildignore+=*/node_modules/*,*/doc/*,*/coverage/*

"tab-important languages
autocmd FileType make setlocal noexpandtab
autocmd FileType python setlocal noexpandtab

"syntax highlighting for the insane
autocmd BufNewFile,BufRead *.pde setf c
autocmd BufNewFile,BufRead *.ino setf c
autocmd BufNewFile,BufRead Rakefile setf ruby
autocmd BufNewFile,BufRead Gemfile setf ruby
autocmd BufNewFile,BufRead Guardfile setf ruby

call textobj#user#plugin('rubyblock', {
      \ 'code': {
      \   'pattern': ['.*\(module\|class\|if\|do\|def\).*\n\s*', '\n\s*end'],
      \   'select-a': 'ar',
      \   'select-i': 'ir',
      \ },
      \})


" Open tabs for a Railsy environment.
"
function! Rails()
  let tabs = [
           \ ['/',               'config/routes.rb'],
           \ ['test',            'test_helper.rb'],
           \ ['app/support',     ''],
           \ ['app/models',      'user.rb'],
           \ ['app/controllers', 'application_controller.rb'],
           \ ['app/helpers',     'application_helper.rb'],
           \ ['app/views',       'layouts/application.html.haml'],
           \ ['app/assets',      'stylesheets/application.css.scss']
        \ ]

  call OpenTabs(tabs)

  " controller
  " test
  " view
  " model
  " route
endfunction

" Hook in the command :Rails to the Rails function
command -nargs=0 Rails :call Rails()


"
"  Open a collection of files in tabs.
"
"  List of ordered pairs where the car is the nerd-tree directory
"  for a tab and the cdr is the relevant file to open in that tab.
"
"  If the directory specified in the car doesn't exist, the tab will
"  not be opened.
"
function! OpenTabs (tabs)
  let success = 0

  for i in a:tabs

    let directory = getcwd() . '/' . i[0] . '/'
    let default_file = directory . i[1]
    let file_type = getftype(default_file)

    if isdirectory(directory) || file_type == 'file'
      if success
        execute 'tabnew'
      endif

      if file_type == 'file'
        "execute 'normal a e ' . default_file
        execute 'e ' . default_file
      endif


      if isdirectory(directory)
        execute 'NERDTree ' . directory
        wincmd l
      endif

      let success = 1
    endif

  endfor

endfunction


" If the current directory looks like a Rails website, automagically open all
" the tabs
"if getftype('config/application.rb') == 'file' && has('gui_running')
  "this seems to cause a 'press-enter-to-continue' prompt to happen
  "autocmd GUIEnter * call Rails()
  "autocmd VimEnter * call Rails()
  "call Rails()
"endif
