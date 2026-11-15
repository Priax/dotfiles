# macOS: Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export GOPATH="$HOME/go"
export BUN_INSTALL="$HOME/.bun"
export EDITOR=nvim
export NPM_CONFIG_PREFIX="$HOME/.local"

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

path_append "$GOPATH/bin"
path_append "$HOME/.cabal/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.deno/bin"
path_prepend "$HOME/.ghcup/bin"
path_prepend "$BUN_INSTALL/bin"
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"
export PATH
unset -f path_prepend path_append
