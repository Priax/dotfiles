# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Prepend a directory to PATH only if it isn't already there
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}
path_append() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$PATH:$1" ;;
    esac
}

# macOS: Homebrew (absent sur Linux)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# User specific environment
export GOPATH="$HOME/go"
export BUN_INSTALL="$HOME/.bun"
export EDITOR=nvim

path_append  "$GOPATH/bin"
path_append  "$HOME/.cabal/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.deno/bin"
path_prepend "$HOME/.ghcup/bin"
path_prepend "$BUN_INSTALL/bin"
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"
export PATH
unset -f path_prepend path_append

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# Node version manager (fnm) — falls back to system node when no version is selected
if command -v fnm >/dev/null; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

alias neofetch=fastfetch

# macOS (launchd) et les bureaux Linux fournissent déjà un agent. Sinon (tty, ssh): un seul
# agent partagé par tous les shells, sur un socket fixe, au lieu d'un nouveau par shell.
if [ -z "$SSH_AUTH_SOCK" ]; then
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    ssh-add -l >/dev/null 2>&1
    # 2: aucun agent derrière le socket
    if [ $? -eq 2 ]; then
        rm -f "$SSH_AUTH_SOCK"
        ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
        [ -f ~/.ssh/tsinghua_gitlab ] && ssh-add ~/.ssh/tsinghua_gitlab 2>/dev/null
    fi
fi
