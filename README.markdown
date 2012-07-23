vim-logaling
============

This is a logaling-command wrapper.
You can use logaling-command on Vim.

Dependency
----------
Needless to say, you're a user of logaling-command.  
If not, you have to install logaling-command.

    gem install logaling-command


How to install
-------------
If you use [Vundle](https://github.com/gmarik/vundle.git) it's very easy, you just run command `:BundleInstall tacahiroy/vim-logaling`
on Vim.  
And also put `Bundle 'tacahiroy/vim-logaling'` into `.vimrc`.

If you use [pathogen.vim](https://github.com/tpope/vim-pathogen), you just execute following:

    cd ~/.vim/bundle
    git clone git://github.com/tacahiroy/vim-logaling.git

If you don't use either, you must copy 'autoload', 'plugin' and 'doc'
 directories in $HOME/.vim directory.  
On windows, you must copy to $HOME/vimfiles directory instead of $HOME/.vim.

Related links
--------------

[GitHub/vim-logaling](https://github.com/tacahiroy/vim-logaling)  
[vim.org/vim-logaling](http://www.vim.org/scripts/script.php?script_id=4144)  
[logaling-command](http://logaling.github.com)

License
-------

Copyright (c) 2012 tacahiroy. Distributed under the MIT License.

