# dotfiles

Ma config sur Fedora et macOS: bash, fish, git, nvim, kitty, docker, postgresql…

## Organisation

```
manifest     les fichiers suivis, un par ligne (dossier si la ligne finit par /)
dot          le script de synchro
lib/         son code: common, sync, packages, install, nvim (+ nvim_maint.lua), upgrade, clean
home/        copie de ~           (ex: home/.config/fish/config.fish)
system/      copie de /, en sudo  (ex: system/etc/docker/daemon.json)
firefox/     copie du profil Firefox par défaut (ex: firefox/chrome/userChrome.css)
packages/    listes de paquets: linux/ (dnf, flatpak…), macos/ (brew…)
```

## Utilisation

```sh
dot status     # ce qui a changé
dot diff fish  # le détail, filtré sur « fish »
dot push       # machine → repo, commit, push
dot pull       # git pull, puis repo → machine et plugins nvim
dot upgrade    # met tout à jour
dot clean      # fait de la place
dot defaults   # macOS: réglages système (aussi lancé par dot install)
dot tablette   # Linux: correctif de la télécommande XP-Pen, à relancer après un nouveau noyau
               # si elle ne marche plus
```

`dot pull` sauvegarde dans `~/dotfiles_backup/` ce qu'il remplace. Il refuse d'écraser un fichier
modifié sur la machine: il faut d'abord le pousser avec `dot push`. Ensuite il installe les plugins
nvim aux versions de `lazy-lock.json`, et les parsers et paquets Mason qui manquent.

`dot upgrade` met à jour les paquets système (dnf et flatpak, ou brew), kitty, lazygit et
JetBrainsMono Nerd Font, Rust et les outils cargo, Haskell (versions recommandées par ghcup), Node (dernière LTS
via fnm), les paquets npm globaux, Deno, et dans nvim les plugins, parsers et paquets Mason. Si
`lazy-lock.json` a changé, il faut ensuite faire `dot push`.

`dot clean` vide sans demander les caches, qui se re-téléchargent (dnf/brew, npm, yarn, pip, go,
cargo, ghcup, miniatures, logs de nvim), et retire les plugins sortis de la config nvim. Pour le
reste, il montre ce qu'il compte supprimer et demande:

- paquets devenus inutiles (`dnf autoremove`, `brew autoremove`);
- versions de GHC, HLS, cabal et stack inactives, et stores cabal des GHC désinstallés;
- versions de Node qu'aucun alias fnm ni `.nvmrc` n'utilise;
- parsers et paquets Mason absents de la config nvim;
- journaux système, corbeille, images Docker/Podman;
- sauvegardes de `dot apply` de plus de 30 jours.

Les dossiers du manifest sont copiés en miroir dans les deux sens: `dot apply` retire aussi de la
machine ce qui n'est plus dans le repo (après sauvegarde), sauf les fichiers exclus comme
`fish_variables`.

Le repo est public. `dot push` annule le commit s'il trouve un secret (ses propres motifs, puis
`gitleaks`). Il passe aussi les scripts à `shellcheck` et demande confirmation si quelque chose
ressort.

## Le manifest

- Suivre un nouveau fichier: l'ajouter au manifest, puis `dot push`.
- Fichier propre à un OS: `# linux` ou `# macos` en fin de ligne.
- Fichier du repo posé ailleurs sur une machine: `destination < source`, par exemple
  `~/Library/Fonts/Daydream.ttf < ~/.local/share/fonts/Daydream.ttf  # macos`.
- Fichier du profil Firefox: `firefox:chemin`, le dossier du profil est retrouvé dans `profiles.ini`.

## Nouvelle machine

```sh
curl -fsSL https://raw.githubusercontent.com/Priax/dotfiles/main/bootstrap.sh | bash
```

Même commande sur Fedora et macOS (sur Mac, Homebrew est installé d'abord). Le script installe:

- git, rsync, gitleaks, shellcheck, fish, nvim, kitty et JetBrainsMono Nerd Font;
- ce dont la config nvim a besoin (go, npm, tree-sitter, ripgrep, fd, lazygit, ImageMagick,
  ffmpeg…);
- lazygit, depuis sa release GitHub (absent des dépôts Fedora);
- par leur script officiel: Rust (les toolchains de `rustup.txt`), Haskell via ghcup (+ cabal-fmt
  si on veut), fnm et la dernière LTS de Node, Deno, et kitty sur Linux;
- les paquets npm globaux de `npm-global.txt`, dans `~/.local` (sans sudo, voir
  `NPM_CONFIG_PREFIX` dans `~/.config/env.sh`);
- les dépôts dnf de `dnf-repos.txt` (RPM Fusion, docker-ce, pgAdmin4), puis les paquets de
  `packages/<os>/`, après confirmation;
- sur Linux, l'ajout au groupe `pipewire` pour l'audio temps réel (après reconnexion,
  `ulimit -r` doit afficher 70).

Il déploie les configs, prépare nvim (plugins, parsers, paquets Mason) et propose de passer à fish.
Pour vérifier nvim ensuite: `:checkhealth configs`.

Pas suivi, à refaire à la main:

- les clés SSH et les blocs `Host` de `~/.ssh/config` (les réglages communs sont dans
  `~/.config/ssh/common.conf`, inclus par `dot apply`);
- les clés GPG: copier `~/.gnupg`, ou `gpg --export-secret-keys` puis `gpg --import`;
- `~/.gitconfig.local`, pour ce qui est propre à une machine (git-lfs sur le Mac).

## Applis à installer soi-même

Ni paquet ni installeur scriptable:

- Aseprite
- Soulseek
- Anki
- STM32CubeIDE
- wrk
- Vesktop
- VirtualBox
- Olympus
- FL Studio: prendre l'installeur dans l'archive Image-Line (forum, « FL Studio Installer
  Archive »), puis `fl install <installeur.exe>`. Ensuite, débloquer avec le compte Image-Line et
  réinstaller les plugins tiers (Waves Central, aussi avec `fl install`).

Installées par `dnf.txt`, mais leurs données ne sont pas suivies:

- Steam: se reconnecter et retélécharger les jeux (ou copier `~/.local/share/Steam/steamapps`).
- Krita: réglages, brosses et ressources à refaire (ou copier `~/.local/share/krita` et
  `~/.config/kritarc`).
