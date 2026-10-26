# Lu par tous les zsh, même non interactifs (scripts, outils qui lancent zsh -c): cargo dans le PATH
# (absent sur une machine neuve tant que « dot install » n'a pas installé rustup)
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi
