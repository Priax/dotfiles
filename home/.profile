# Read by non-bash login shells (bash uses .bash_profile instead)
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) PATH="$HOME/.cargo/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.ghcup/bin:"*) ;; *) PATH="$HOME/.ghcup/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.deno/bin:"*) ;; *) PATH="$HOME/.deno/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.cabal/bin:"*) ;; *) PATH="$PATH:$HOME/.cabal/bin" ;; esac
export PATH
