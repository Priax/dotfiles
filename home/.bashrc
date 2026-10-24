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

# User specific environment
export GOPATH="$HOME/go"
export BUN_INSTALL="$HOME/.bun"
export FLYCTL_INSTALL="$HOME/.fly"
export EDITOR=nvim

path_append  "$GOPATH/bin"
path_append  "$HOME/.cabal/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.deno/bin"
path_prepend "$HOME/.ghcup/bin"
path_prepend "$FLYCTL_INSTALL/bin"
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

if [ -z "$SSH_AUTH_SOCK" ]; then
   eval "$(ssh-agent -s)" > /dev/null
   ssh-add ~/.ssh/tsinghua_gitlab 2>/dev/null
fi
