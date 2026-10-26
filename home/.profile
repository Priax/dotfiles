# Read by non-bash login shells (bash uses .bash_profile instead)
# macOS: Homebrew (absent sur Linux)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) PATH="$HOME/.cargo/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.ghcup/bin:"*) ;; *) PATH="$HOME/.ghcup/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.deno/bin:"*) ;; *) PATH="$HOME/.deno/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.cabal/bin:"*) ;; *) PATH="$PATH:$HOME/.cabal/bin" ;; esac
export PATH
