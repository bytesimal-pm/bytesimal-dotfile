# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# Options
setopt AUTO_CD INTERACTIVE_COMMENTS

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Keybinds (emacs style)
bindkey -e
bindkey '^[[1;5D' backward-word       # Ctrl+Left
bindkey '^[[1;5C' forward-word        # Ctrl+Right
bindkey '^[[H'    beginning-of-line   # Home
bindkey '^[[F'    end-of-line         # End
bindkey '^[[3~'   delete-char         # Delete

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Plugins (installed with pacman)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#555555'
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Fuzzy finder: Ctrl+R history, Ctrl+T files, Alt+C cd into folder
if command -v fzf >/dev/null; then
    export FZF_DEFAULT_OPTS="--height 40% --layout reverse --border rounded --prompt '❯ ' --pointer '▌' --marker '•' \
--color fg:#ffffff,bg:-1,hl:#ffffff:bold:underline,fg+:#000000,bg+:#ffffff,hl+:#000000:bold:underline \
--color border:#ffffff,prompt:#ffffff,pointer:#ffffff,marker:#ffffff,info:#555555,spinner:#555555,header:#707070"
    if command -v fd >/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
        # Tab completion lists only the folder's own entries, hidden ones last
        # $1 = folder, rest = extra fd flags
        _fzf_ls() {
            local dir=$1; shift
            { fd -d1 "$@" . "$dir" | sort
              fd -d1 -H --exclude .git "$@" '^\.' "$dir" | sort } | sed 's|^\./||'
        }
        _fzf_compgen_path() { _fzf_ls "$1" }
        _fzf_compgen_dir()  { _fzf_ls "$1" --type d }
    fi
    # Tab opens fzf for files/folders (default needs a ** trigger)
    export FZF_COMPLETION_TRIGGER=''
    source <(fzf --zsh)
fi

# Prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

# Must be loaded last
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
