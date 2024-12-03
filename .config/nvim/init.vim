set nobackup
set nowritebackup
set noshowmode
set noshowcmd

set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.config/.vimrc

set undodir=~/.config/nvim/backups
set guifont=Fira\ Code:h16
let g:copilot_node_command = '/Users/robert/.asdf/installs/nodejs/22.11.0/bin/node'

" multi-tab interactions to behave like a gui
nmap <D-t> :tabnew<CR>
nmap <S-D-]> :tabnext<CR>
nmap <S-D-[> :tabprevious<CR>
nmap <S-D-}> :tabnext<CR>
nmap <S-D-{> :tabprevious<CR>

if exists('g:vv')
  VVset nosimplefullscreen
endif
