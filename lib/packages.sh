# shellcheck shell=bash
# Listes de paquets: export (dot save) et installation (dot install)

# dump <fichier> <commande…>: écrit la sortie de la commande dans le fichier. Si la commande
# échoue ou ne sort rien, l'ancienne liste est gardée: une liste vide poussée par erreur ferait
# installer rien du tout sur une nouvelle machine.
dump() {
    local out=$1
    shift
    local tmp err
    tmp="$(mktemp)"
    err="$(mktemp)"
    if ! "$@" >"$tmp" 2>"$err"; then
        rm -f "$tmp"
        # la dernière ligne d'erreur donne en général la cause (avec Python, sous la trace)
        fail "  échec, liste conservée: ${out#"$REPO_DIR"/} ($(grep . "$err" | tail -n 1))"
    elif [[ -s $tmp ]]; then
        mv "$tmp" "$out"
        printf '  %s (%s)\n' "${out#"$REPO_DIR"/}" "$(wc -l <"$out" | tr -d ' ')"
    else
        rm -f "$tmp"
        [[ -s $out ]] &&
            warn "  liste vide, ancienne conservée: ${out#"$REPO_DIR"/} (à supprimer à la main si c'est voulu)"
    fi
    rm -f "$err"
}

pkg_dnf() { dnf repoquery --userinstalled --leaves --qf '%{name}\n' | sort -u; }
pkg_dnf_repos() { dnf repolist --enabled | awk 'NR>1 {print $1}' | sort -u; }
pkg_flatpak() { flatpak list --app --columns=application | sort -u; }

# Une ligne par outil, avec les arguments de « cargo install » lus dans .crates2.json.
# « cargo install --list » ne donne que les noms, et sqlx-cli serait alors réinstallé sans
# --no-default-features --features postgres.
pkg_cargo() {
    local crates="${CARGO_HOME:-$HOME/.cargo}/.crates2.json"
    if [[ ! -s $crates ]]; then
        # vu sur le Mac: fichier absent ou vide, on n'a que les noms
        cargo install --list | awk '/^[^ ]/ {print $1}'
        return
    fi
    python3 -I - "$crates" <<'PY'
import json, sys
from urllib.parse import parse_qs, urlsplit

for key, info in sorted(json.load(open(sys.argv[1]))["installs"].items()):
    name, _, source = key.split(" ", 2)
    source = source.strip("()")
    args = [name]
    if source.startswith("path+"):
        print(f"{name}: installé depuis un dossier local, pas suivi", file=sys.stderr)
        continue
    if source.startswith("git+"):
        url = urlsplit(source[4:].split("#")[0])
        args += ["--git", url._replace(query="").geturl()]
        for ref, values in parse_qs(url.query).items():
            if ref in ("branch", "tag", "rev"):
                args += [f"--{ref}", values[0]]
    if info.get("no_default_features"):
        args.append("--no-default-features")
    if info.get("all_features"):
        args.append("--all-features")
    if info.get("features"):
        args += ["--features", ",".join(info["features"])]
    print(" ".join(args))
PY
}

# Installe les outils d'une liste de pkg_cargo. cargo ne recompile que ce qui manque, a changé
# de version ou d'options.
install_cargo_tools() {
    local line args
    while read -r line; do
        [[ -n $line ]] || continue
        read -ra args <<<"$line"
        cargo install "${args[@]}" || fail "  échec de ${args[0]}"
    done <"$1"
    return 0
}

pkg_pip() { pip list --user --not-required --format=freeze | cut -d= -f1; }
pkg_brew() { brew leaves --installed-on-request; }
pkg_brew_cask() { brew list --cask -1; }

# Une ligne par toolchain: « nom default|- composants|- cibles ». Le triplet de l'hôte est retiré
# (nightly-x86_64-unknown-linux-gnu → nightly) pour que la liste serve aussi sur l'autre OS.
pkg_rustup() {
    local host def tc comps targets
    host="$(rustup show | awk '/^Default host:/ {print $3}')"
    def="$(rustup default | awk '{print $1}')"
    rustup toolchain list | awk '{print $1}' | while read -r tc; do
        # les rust-std-<cible> sont listés à part, comme cibles
        comps="$(rustup component list --installed --toolchain "$tc" | grep -v '^rust-std-' | sed "s/-$host\$//" | paste -sd, -)"
        targets="$(rustup target list --installed --toolchain "$tc" | { grep -vx "$host" || true; } | paste -sd, -)"
        printf '%s %s %s %s\n' "${tc%-"$host"}" "$([[ $tc == "$def" ]] && echo default || echo -)" "${comps:--}" "${targets:--}"
    done
}

# Paquets npm globaux: installés avec le npm du système (pas celui d'une version fnm), dans
# ~/.local comme le veut ~/.config/env.sh. Repris ici pour un dot lancé avant que env.sh soit
# en place (dot install).
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.local}"

system_npm() {
    local n
    for n in /usr/bin/npm /opt/homebrew/bin/npm /usr/local/bin/npm; do
        if [[ -x $n ]]; then
            echo "$n"
            return
        fi
    done
    return 1
}

# Nom seul, sauf pour une préversion (bêta, rc…) notée nom@version: sinon une nouvelle machine
# installerait la dernière stable (ex: ngrok 5 bêta → 4).
pkg_npm() {
    local npm
    npm="$(system_npm)" || return 1
    "$npm" ls -g --depth=0 --json | python3 -I -c '
import json, sys
for name, info in sorted(json.load(sys.stdin).get("dependencies", {}).items()):
    if name == "npm":
        continue
    version = info.get("version", "")
    print(f"{name}@{version}" if "-" in version else name)
'
}

export_packages() {
    info "Export des listes de paquets..."
    local d="$PKG_DIR"
    mkdir -p "$d"
    have dnf && dump "$d/dnf.txt" pkg_dnf
    have dnf && dump "$d/dnf-repos.txt" pkg_dnf_repos
    have flatpak && dump "$d/flatpak.txt" pkg_flatpak
    have brew && dump "$d/brew.txt" pkg_brew
    have brew && dump "$d/brew-cask.txt" pkg_brew_cask
    have cargo && dump "$d/cargo.txt" pkg_cargo
    have pip && dump "$d/pip.txt" pkg_pip
    have rustup && dump "$d/rustup.txt" pkg_rustup
    system_npm >/dev/null && dump "$d/npm-global.txt" pkg_npm
    return 0
}

install_packages() {
    local d="$PKG_DIR"
    if [[ -s $d/dnf-repos.txt ]]; then
        info "Dépôts utilisés sur l'ancienne machine:"
        tr '\n' ' ' <"$d/dnf-repos.txt"
        echo
        if ask "Ajouter ceux qu'on sait configurer (RPM Fusion, docker-ce, pgAdmin4) ?"; then
            setup_dnf_repos "$d/dnf-repos.txt"
        else
            info "Les paquets venant de dépôts non configurés seront ignorés."
        fi
    fi
    if [[ -s $d/dnf.txt ]] && ask "Installer les paquets dnf ($(wc -l <"$d/dnf.txt")) ?"; then
        xargs -a "$d/dnf.txt" sudo dnf install -y --skip-unavailable
    fi
    if [[ -s $d/flatpak.txt ]] && have flatpak && ask "Installer les flatpaks ?"; then
        xargs -a "$d/flatpak.txt" flatpak install -y flathub
    fi
    if [[ -s $d/brew.txt ]] && have brew && ask "Installer les paquets brew ($(wc -l <"$d/brew.txt" | tr -d ' ')) ?"; then
        xargs brew install <"$d/brew.txt" || true
    fi
    if [[ -s $d/brew-cask.txt ]] && have brew && ask "Installer les casks brew ?"; then
        xargs brew install --cask <"$d/brew-cask.txt" || true
    fi
    if [[ -s $d/cargo.txt ]] && have cargo && ask "Installer les outils cargo ?"; then
        install_cargo_tools "$d/cargo.txt"
    fi
    local npm
    if [[ -s $d/npm-global.txt ]] && npm="$(system_npm)" && ask "Installer les paquets npm globaux ?"; then
        xargs "$npm" install -g <"$d/npm-global.txt" || true
        # pnpm et yarn passent par corepack
        if grep -qx corepack "$d/npm-global.txt"; then
            "$("$npm" prefix -g)/bin/corepack" enable || true
        fi
    fi
    if [[ -s $d/pip.txt ]] && have pip && ask "Installer les paquets pip (--user) ?"; then
        xargs pip install --user <"$d/pip.txt" || true
    fi
}

# Groupe pipewire: priorité temps réel et memlock pour l'audio (Fedora:
# /etc/security/limits.d/25-pw-rlimits.conf). Sans lui, `ulimit -r` vaut 0 et les petits
# buffers craquent (FL Studio…).
setup_groups() {
    [[ $OS == linux ]] || return 0
    local g missing=()
    for g in pipewire; do
        getent group "$g" >/dev/null || continue
        # id lit /etc/group, donc un ajout pas encore actif dans la session compte déjà
        id -nG "$USER" | tr ' ' '\n' | grep -qx "$g" || missing+=("$g")
    done
    ((${#missing[@]})) || return 0
    if ask "Ajouter $USER au groupe ${missing[*]} (temps réel pour l'audio) ?"; then
        for g in "${missing[@]}"; do
            sudo usermod -aG "$g" "$USER" || fail "  échec de l'ajout au groupe $g"
        done
        info "Pris en compte à la prochaine connexion (vérifier: ulimit -r)."
    fi
}
