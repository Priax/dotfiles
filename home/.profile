# Shells de connexion autres que bash (zsh le lit via ~/.zprofile). bash, lui, lit
# ~/.bash_profile puis ~/.bashrc, qui chargent le même ~/.config/env.sh.
if [ -f "$HOME/.config/env.sh" ]; then
    . "$HOME/.config/env.sh"
fi
