Various dot files to keep things portable and so I can always feel 'at home' wherever I go....

### Notes for getting setup on a new machine:

Prerequisites:

- install fish shell

Copy and paste this snippet into a running fish shell:

```
alias dots="/usr/bin/git --git-dir=$HOME/.dots.git/ --work-tree=$HOME"
git clone --bare git@github.com:robacarp/config_files.git $HOME/.dots.git
dots checkout -f
dots config --local status.showUntrackedFiles no
dots config user.name 'rob' ; dots config user.email 'robacarp@users.noreply.github.com'
vim +'PlugInstall' +'qall!'
```
