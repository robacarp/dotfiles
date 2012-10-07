filetype off
call pathogen#infect()
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
"instead, only highlight the one I'm trying to look at
set showmatch

"sprinkle a little salt in the regexen to make it more palatable to vim
nnoremap / /\v
vnoremap / /\v

"global regexin easier
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

"my little pinky isa bit slow coming off that shift key sometimes.
command W w
command Q q
command Wq wq
command Wbn w|bn
command Wbp w|bp
command Bn bn
command Bp bp
command Ls ls

"tab-important languages
au FileType make setlocal noexpandtab
au FileType python setlocal noexpandtab

"syntax highlighting for the insane
au BufNewFile,BufRead *.pde setf c
au BufNewFile,BufRead *.ino setf c
au BufNewFile,BufRead Rakefile setf ruby
au BufNewFile,BufRead Gemfile setf ruby

" A function to open up my Rails tabs workflow.
function Rails()
  let tabs = [ 'test', 'app/support', 'app/models', 'app/mailers', 'app/controllers', 'app/assets' ]

  for i in tabs
    if isdirectory(i)
      execute 'tabnew ' . i
    endif
  endfor
endfunction

" If the current directory looks like a Rails website,
if isdirectory('app') && isdirectory('config')
  call Rails()
end

" Hook in the command :Rails to the Rails function
command -nargs=0 Rails :call Rails()
