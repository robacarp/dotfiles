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
set laststatus=1   "show status bar with >1 windows only (2 => always)

set list
set listchars=tab:>\ ,trail:·

"gui options
"   No menubar, no always scrollbars
set guioptions=e
set guifont=Monaco:h12

"make j/k behave soundly.
nnoremap j gj
nnoremap k gk

" dont deselect on indent
" vnoremap < <gv
" vnoremap > >gv

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
set nohlsearch

"global regexin easier
set gdefault    "automagically adds /g on a regex. /g to disable

" Keep undo history across sessions, by storing in file.
if has('persistent_undo')
  silent !mkdir ~/.vim/backups > /dev/null 2>&1
  set undodir=~/.vim/backups
  set undofile
endif

set background=dark
"other great options: anotherdark, wombat, vividchalk
color mustang

"my little pinky isa bit slow coming off that shift key sometimes.
command! W w
command! Q q
command! Wq wq
command! Wbn w|bn
command! Wbp w|bp

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
command! -nargs=0 Rails :call Rails()


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
