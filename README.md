# dotfiles

Config perso (Fedora et macOS): bash, fish, git, nvim, kitty, docker, postgresql…

## Organisation

```
manifest     liste des fichiers suivis (une ligne = un fichier ou dossier/)
dot          script de synchro
home/        miroir de ~        (ex: home/.config/fish/config.fish)
system/      miroir de /, sudo  (ex: system/etc/docker/daemon.json)
packages/    listes de paquets par OS: linux/ (dnf, flatpak…), macos/ (brew…)
```

## Utilisation

```sh
dot status     # qu'est-ce qui a changé ?
dot diff fish  # voir le détail (filtre optionnel)
dot push       # machine → repo, commit, push
dot pull       # git pull, repo → machine (l'existant est sauvegardé dans ~/dotfiles_backup/)
```

Suivre un nouveau fichier: l'ajouter dans `manifest`, puis `dot push`.
Entrée propre à un OS: ajouter `# linux` ou `# macos` en fin de ligne dans `manifest`.

## Nouvelle machine

```sh
curl -fsSL https://raw.githubusercontent.com/Priax/dotfiles/main/bootstrap.sh | bash
```

Même commande sur Fedora et sur macOS. Installe git, rsync, fish, nvim, kitty et
JetBrainsMono Nerd Font (sur Mac: Homebrew d'abord, puis bash et rsync récents),
déploie les configs, propose d'installer les paquets de `packages/<os>/` et de
passer à fish.

À refaire à la main (non suivi, volontairement): les clés SSH (`~/.ssh`) et
`~/.gitconfig.local` (réglages propres à la machine, ex: git-lfs sur le Mac).
Puis, dans nvim: `:MasonInstallAll`.
