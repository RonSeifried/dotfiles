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
    colored-man-pages
    sudo
    you-should-use
    zsh-bat
    aliases
    zsh-syntax-highlighting
)
source "$ZSH/oh-my-zsh.sh"

########## ZSH PLUGIN COLORS ##########
# wallust salience generates ~8 unique slots: color0=bg, color1–5=dim accents,
# color6/7/8/15=readable. Default plugin styles use red/green/yellow (color1–3)
# which become unreadable on monochromatic wallpapers. Override to map plugin
# colors to readable slots only.

# zsh-autosuggest (greyed completion suggestion). color8 is the medium-tint
# slot — visible but secondary, exactly what we want for ghost text.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# zsh-syntax-highlighting: remap every visible style to a readable slot.
# Semantic intent is preserved via slot choice (warm = command/typo,
# cool = builtin/function, bright = string).
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=15'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=5,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=6,bold'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=6'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=6'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=6,underline'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=15'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=7,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=15'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=7'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=15'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=6'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=5'
ZSH_HIGHLIGHT_STYLES[command-substitution]='fg=15'
ZSH_HIGHLIGHT_STYLES[process-substitution]='fg=15'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=7'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=7'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=15'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=15'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=15'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=6'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[assign]='fg=6'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=15,bold'
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=8'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=8'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=6'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=6,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=6'
ZSH_HIGHLIGHT_STYLES[command]='fg=6,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=6'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=6'

########## ENVIRONMENT ##########

# PATH
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

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
# alias fastfetch='fastfetch --logo-type kitty'

# Confirm before overwriting files
setopt interactivecomments
setopt noclobber

# Enable completion
autoload -U compinit && compinit

########## Startup ##########

# Fastfetch on terminal open (fallback to neofetch)
if command -v fastfetch &> /dev/null; then
  "$HOME/.config/scripts/fastfetch-launcher.sh"
elif command -v neofetch &> /dev/null; then
  neofetch
fi

########## END ##########
