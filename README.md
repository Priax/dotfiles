# dotfiles

Config perso (Fedora et macOS): bash, fish, git, nvim, kitty, docker, postgresql…

## Organisation

```
manifest     liste des fichiers suivis (une ligne = un fichier ou dossier/)
dot          script de synchro
home/        miroir de ~        (ex: home/.config/fish/config.fish)
system/      miroir de /, sudo  (ex: system/etc/docker/daemon.json)
firefox/     miroir du profil Firefox par défaut (ex: firefox/chrome/userChrome.css)
packages/    listes de paquets par OS: linux/ (dnf, flatpak…), macos/ (brew…)
```

## Utilisation

```sh
dot status     # qu'est-ce qui a changé ?
dot diff fish  # voir le détail (filtre optionnel)
dot push       # machine → repo, commit, push
dot pull       # git pull, repo → machine (l'existant est sauvegardé dans ~/dotfiles_backup/),
               # puis plugins nvim (lazy-lock.json), parsers et paquets Mason manquants
dot upgrade    # met tout à jour (voir plus bas)
dot clean      # retire paquets inutilisés et caches (voir plus bas)
dot defaults   # macOS: réglages système (packages/macos/defaults.sh), aussi lancé par dot install
```

`dot upgrade`: paquets système (dnf + flatpak, ou brew), kitty et JetBrainsMono Nerd Font
si une nouvelle version est sortie, toolchains Rust et outils cargo, Haskell (versions
recommandées par ghcup), dernière LTS de Node (fnm), paquets npm globaux, Deno, et
dans nvim: plugins (`lazy-lock.json` change: `dot push` ensuite), parsers treesitter, paquets Mason.

`dot clean`: vide sans demander les caches, re-téléchargés au besoin (dnf/brew, npm, yarn, pip,
go, cargo, ghcup, miniatures, logs de nvim). Tout ce qui est *déduit* est listé puis confirmé:
paquets devenus inutiles (dnf/brew autoremove), store cabal des GHC désinstallés, parsers et
paquets Mason hors de la config nvim (peut-être installés à la main), versions inactives de
GHC/HLS/cabal/stack (laissées par `dot upgrade`), versions de Node sans alias fnm, journaux système,
corbeille, images Docker/Podman. Les plugins retirés de la config nvim partent sans demander
(lazy le déduit de la config elle-même).

Suivre un nouveau fichier: l'ajouter dans `manifest`, puis `dot push`.
Entrée propre à un OS: ajouter `# linux` ou `# macos` en fin de ligne dans `manifest`.
Même fichier du repo à un autre emplacement selon l'OS: `destination < source`
(ex: `~/Library/Fonts/Daydream.ttf < ~/.local/share/fonts/Daydream.ttf  # macos`).
Fichier du profil Firefox: `firefox:chemin` (le dossier du profil est retrouvé via `profiles.ini`).

## Nouvelle machine

```sh
curl -fsSL https://raw.githubusercontent.com/Priax/dotfiles/main/bootstrap.sh | bash
```

Même commande sur Fedora et sur macOS. Installe git, rsync, fish, nvim, kitty et
JetBrainsMono Nerd Font (sur Mac: Homebrew d'abord, puis bash et rsync récents),
déploie les configs, propose d'installer les paquets de `packages/<os>/` et de
passer à fish.

Installe aussi:

- les dépendances de la config nvim (go, npm, tree-sitter, ripgrep, ImageMagick, ffmpeg…);
- par leur script officiel, ce qu'aucun gestionnaire de paquets ne suit: Rust (toutes les
  toolchains de `rustup.txt`, avec composants et cibles), Haskell via ghcup (versions
  recommandées du moment, + cabal-fmt en option), fnm (+ dernière LTS de Node), Deno,
  et kitty sur Linux;
- les dépôts dnf tiers de `dnf-repos.txt` (RPM Fusion, docker-ce, pgAdmin4), avant les paquets;
- les paquets npm globaux de `npm-global.txt` (npm du système, pas celui de fnm).

JetBrainsMono Nerd Font: sur Linux, `dot install` et `dot pull` la mettent à jour quand une
nouvelle version sort (version notée dans `~/.local/share/fonts/JetBrainsMonoNerdFont/.version`).
Sur Mac, c'est un cask: `brew upgrade`.

Et pour nvim, à la fin: les plugins (versions de `lazy-lock.json`), les parsers treesitter et les
paquets Mason, que faisaient `:MasonInstallAll` et `:TSInstallAll`. Vérification dans nvim:
`:checkhealth configs` (outils externes, paquets Mason, parsers).

À refaire à la main (non suivi, volontairement): les clés SSH et les blocs `Host` de `~/.ssh/config`
(les réglages communs, eux, sont dans `~/.config/ssh/common.conf`, que `dot apply` inclut en tête de
`~/.ssh/config`), les clés GPG
(`~/.gnupg`, à copier depuis l'ancienne machine ou via `gpg --export-secret-keys` / `gpg --import`)
et `~/.gitconfig.local` (réglages propres à la machine, ex: git-lfs sur le Mac).

## Applis à installer soi-même

Ni paquet ni installeur scriptable, à récupérer sur leur site:

- Aseprite
- Soulseek
- Anki
- STM32CubeIDE
- wrk
- Vesktop (RPM de la release GitHub)
- VirtualBox (dépôt Oracle)
