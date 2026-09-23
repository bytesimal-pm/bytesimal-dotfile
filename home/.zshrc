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

# git-protocol {https|ssh} [remote]: switch a remote's URL between
# https://host/owner/repo.git and git@host:owner/repo.git.
# With no protocol, prints the current URL.
git-protocol() {
    local remote=${2:-origin} url host repo new
    url=$(git remote get-url "$remote") || return
    if [[ $url =~ '^https?://([^/]+)/(.+)$' ]]; then
        host=$match[1] repo=$match[2]
    elif [[ $url =~ '^(ssh://)?[^@]+@([^:/]+)[:/](.+)$' ]]; then
        host=$match[2] repo=$match[3]
    else
        print -u2 "git-protocol: can't parse $remote URL: $url"
        return 1
    fi
    repo=${repo%.git}.git

    case $1 in
        https) new="https://$host/$repo" ;;
        ssh)   new="git@$host:$repo" ;;
        "")    print "$remote: $url"; return ;;
        *)     print -u2 "usage: git-protocol {https|ssh} [remote]"; return 1 ;;
    esac

    git remote set-url "$remote" "$new" && print "$remote: $url -> $new"
}
_git-protocol() { _arguments '1:protocol:(https ssh)' '2:remote:($(git remote 2>/dev/null))' }
compdef _git-protocol git-protocol

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
