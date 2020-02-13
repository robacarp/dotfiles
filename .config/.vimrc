source ~/.dotfiles/.config/.vim-plugins

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
endif

"make j/k behave soundly.
nnoremap j gj
nnoremap k gk

" F row actions
map <F3> :set invnumber<CR>
map <F5> :VCSBlame<CR>
map <F9> :set invhlsearch<CR> :set invcursorcolumn<CR> :set invcursorline<CR>

set timeoutlen=400

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
set nohlsearch


" Systastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_quiet_messages = { "type": "style" }

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

set background=dark
"other great options: anotherdark, wombat, vividchalk, mustang
color zmrok

"my little pinky isa bit slow coming off that shift key sometimes.
command! W w
command! Wall wall
command! Bd bd
command! Q q
command! Wq wq

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
