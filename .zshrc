########## ZSH ##########

# Enable Starship
export ZSH="$HOME/.oh-my-zsh"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# pywal
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
  . "$HOME/.cache/wal/colors.sh"
fi

# Starship Prompt
eval "$(starship init zsh)"

# Theme
ZSH_THEME=""

# Plugins (oh-my-zsh)
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    colored-man-pages
    sudo
    you-should-use
    zsh-bat
    aliases
)
source $ZSH/oh-my-zsh.sh

########## ENVIRONMENT ##########

# PATH
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Default editor
export EDITOR="nvim"
export VISUAL="nvim"

# AUR Helper (change to yay if preferred)
export aurhelper="yay"

########## HISTORY ##########

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history
setopt hist_verify
setopt share_history
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_ignore_space

# Ignore trivial commands from history (ZSH-compatible)
zshaddhistory() {
  local line="${1%%$'\n'}"
  [[ "$line" != "ls"* && "$line" != "cd"* && "$line" != "pwd" && "$line" != "exit" && "$line" != "date" && "$line" != *"--help" ]]
}

########## QUALITY OF LIFE ##########

# Navigation shortcuts
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Quick sudo !!
alias please='sudo $(fc -ln -1)'

# mkdir always recursive
alias mkdir='mkdir -p'

# Extract anything
extract () {
  if [ -f "$1" ] ; then
    case $1 in
        *.tar.bz2)   tar xjf "$1"   ;;
        *.tar.gz)    tar xzf "$1"   ;;
        *.bz2)       bunzip2 "$1"   ;;
        *.rar)       unrar x "$1"   ;;
        *.gz)        gunzip "$1"    ;;
        *.tar)       tar xf "$1"    ;;
        *.tbz2)      tar xjf "$1"   ;;
        *.tgz)       tar xzf "$1"   ;;
        *.zip)       unzip "$1"     ;;
        *.Z)         uncompress "$1";;
        *.7z)        7z x "$1"      ;;
        *)           echo "'$1' cannot be extracted" ;;
    esac
  else
    echo "'$1' is not a valid file!"
  fi
}

# Fast search
alias f='find . -type f -iname'

# Better grep
alias grep='grep --color=auto'

# Faster pacman
alias update='sudo pacman -Syu'

# Random aliases
alias c='clear'                                                        # clear terminal
alias l='eza -lh --icons=auto'                                         # long list
alias ls='eza -1 --icons=auto'                                         # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto'                                       # long list dirs
alias lt='eza --icons=auto --tree'                                     # list folder as tree
alias un='$aurhelper -Rns'                                             # uninstall package
alias up='$aurhelper -Syu'                                             # update system/package/aur
alias pl='$aurhelper -Qs'                                              # list installed package
alias pa='$aurhelper -Ss'                                              # list available package
alias pc='$aurhelper -Sc'                                              # remove unused cache
alias po='$aurhelper -Qtdq | $aurhelper -Rns -'                        # remove unused packages
alias vc='code'                                                        # gui code editor
alias fastfetch='fastfetch --logo-type kitty'

# Confirm before overwriting files
setopt interactivecomments
setopt noclobber

# Enable completion
autoload -U compinit && compinit

########## Startup ##########

# Neofetch on terminal open (only for interactive shells, use fastfetch if available)
if command -v neofetch &> /dev/null; then
  neofetch
else
  fastfetch
fi

########## END ##########

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/ron/.lmstudio/bin"
# End of LM Studio CLI section
