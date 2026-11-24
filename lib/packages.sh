# shellcheck shell=bash
# Listes de paquets: export (dot save) et installation (dot install)

repo_relative() { echo "${1#"$REPO_DIR"/}"; }

line_count() { wc -l <"$1" | tr -d ' '; }

# dump <fichier> <commande…>: écrit la sortie de la commande dans le fichier.
# Si la commande échoue ou ne sort rien, l'ancienne liste est gardée.
dump() {
    local out=$1
    shift

    local name tmp err
    name="$(repo_relative "$out")"
    tmp="$(mktemp)"
    err="$(mktemp)"

    if ! "$@" >"$tmp" 2>"$err"; then
        rm -f "$tmp"
        fail "  échec, liste conservée: $name ($(grep . "$err" | tail -n 1))"
    elif [[ -s $tmp ]]; then
        mv "$tmp" "$out"
        printf '  %s (%s)\n' "$name" "$(line_count "$out")"
    else
        rm -f "$tmp"
        if [[ -s $out ]]; then
            warn "  liste vide, ancienne conservée: $name (à supprimer à la main si c'est voulu)"
        fi
    fi

    rm -f "$err"
}

pkg_dnf() { dnf repoquery --userinstalled --leaves --qf '%{name}\n' | sort -u; }
pkg_dnf_repos() { dnf repolist --enabled | awk 'NR > 1 { print $1 }' | sort -u; }
pkg_flatpak() { flatpak list --app --columns=application | sort -u; }
pkg_pip() { pip list --user --not-required --format=freeze | cut -d= -f1; }
pkg_brew() { brew leaves --installed-on-request; }
pkg_brew_cask() { brew list --cask -1; }

pkg_cargo() {
    local crates="${CARGO_HOME:-$HOME/.cargo}/.crates2.json"

    if [[ ! -s $crates ]]; then
        cargo install --list | awk '/^[^ ]/ { print $1 }'
        return
    fi

    python3 -I - "$crates" <<'PY'
import json, sys
from urllib.parse import parse_qs, urlsplit

installs = json.load(open(sys.argv[1]))["installs"]

for key, info in sorted(installs.items()):
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

install_cargo_tools() {
    local line
    local args

    while read -r line; do
        [[ -n $line ]] || continue

        read -ra args <<<"$line"
        cargo install "${args[@]}" || fail "  échec de ${args[0]}"
    done <"$1"

    return 0
}

# Une ligne par toolchain: « nom default|- composants|- cibles ».
toolchain_components() {
    local tc=$1
    local host=$2

    rustup component list --installed --toolchain "$tc" |
        grep -v '^rust-std-' |
        sed "s/-$host\$//" |
        paste -sd, -
}

toolchain_targets() {
    local tc=$1
    local host=$2

    rustup target list --installed --toolchain "$tc" |
        { grep -vx "$host" || true; } |
        paste -sd, -
}

pkg_rustup() {
    local host default_tc tc is_default comps targets
    host="$(rustup show | awk '/^Default host:/ { print $3 }')"
    default_tc="$(rustup default | awk '{ print $1 }')"

    rustup toolchain list | awk '{ print $1 }' | while read -r tc; do
        is_default=-
        if [[ $tc == "$default_tc" ]]; then
            is_default=default
        fi

        comps="$(toolchain_components "$tc" "$host")"
        targets="$(toolchain_targets "$tc" "$host")"

        printf '%s %s %s %s\n' "${tc%-"$host"}" "$is_default" "${comps:--}" "${targets:--}"
    done
}

# Paquets npm globaux: installés avec le npm du système
# Dans ~/.local comme le veut ~/.config/env.sh.
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

pkg_npm() {
    local npm
    npm="$(system_npm)" || return 1

    "$npm" ls -g --depth=0 --json | python3 -I -c '
import json, sys

deps = json.load(sys.stdin).get("dependencies", {})

for name, info in sorted(deps.items()):
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

    if have dnf; then
        dump "$d/dnf.txt" pkg_dnf
        dump "$d/dnf-repos.txt" pkg_dnf_repos
    fi
    if have flatpak; then
        dump "$d/flatpak.txt" pkg_flatpak
    fi
    if have brew; then
        dump "$d/brew.txt" pkg_brew
        dump "$d/brew-cask.txt" pkg_brew_cask
    fi
    if have cargo; then
        dump "$d/cargo.txt" pkg_cargo
    fi
    if have pip; then
        dump "$d/pip.txt" pkg_pip
    fi
    if have rustup; then
        dump "$d/rustup.txt" pkg_rustup
    fi
    if system_npm >/dev/null; then
        dump "$d/npm-global.txt" pkg_npm
    fi

    return 0
}

install_dnf_repos() {
    local list="$PKG_DIR/dnf-repos.txt"
    [[ -s $list ]] || return 0

    info "Dépôts utilisés sur l'ancienne machine:"
    tr '\n' ' ' <"$list"
    echo

    if ask "Ajouter ceux qu'on sait configurer (RPM Fusion, docker-ce, gh-cli, pgAdmin4) ?"; then
        setup_dnf_repos "$list"
    else
        info "Les paquets venant de dépôts non configurés seront ignorés."
    fi
}

install_npm_packages() {
    local list="$PKG_DIR/npm-global.txt"
    local npm

    [[ -s $list ]] || return 0
    npm="$(system_npm)" || return 0
    ask "Installer les paquets npm globaux ?" || return 0

    xargs "$npm" install -g <"$list" || true

    # pnpm et yarn passent par corepack
    if grep -qx corepack "$list"; then
        "$("$npm" prefix -g)/bin/corepack" enable || true
    fi
}

install_packages() {
    local d="$PKG_DIR"

    install_dnf_repos

    if [[ -s $d/dnf.txt ]] && ask "Installer les paquets dnf ($(line_count "$d/dnf.txt")) ?"; then
        xargs -a "$d/dnf.txt" sudo dnf install -y --skip-unavailable
    fi

    if [[ -s $d/flatpak.txt ]] && have flatpak && ask "Installer les flatpaks ?"; then
        xargs -a "$d/flatpak.txt" flatpak install -y flathub
    fi

    if [[ -s $d/brew.txt ]] && have brew && ask "Installer les paquets brew ($(line_count "$d/brew.txt")) ?"; then
        xargs brew install <"$d/brew.txt" || true
    fi

    if [[ -s $d/brew-cask.txt ]] && have brew && ask "Installer les casks brew ?"; then
        xargs brew install --cask <"$d/brew-cask.txt" || true
    fi

    if [[ -s $d/cargo.txt ]] && have cargo && ask "Installer les outils cargo ?"; then
        install_cargo_tools "$d/cargo.txt"
    fi

    install_npm_packages

    if [[ -s $d/pip.txt ]] && have pip && ask "Installer les paquets pip (--user) ?"; then
        xargs pip install --user <"$d/pip.txt" || true
    fi
}

in_group() {
    id -nG "$USER" | tr ' ' '\n' | grep -qx "$1"
}

setup_groups() {
    [[ $OS == linux ]] || return 0

    local missing=()
    local g

    for g in pipewire; do
        getent group "$g" >/dev/null || continue
        in_group "$g" || missing+=("$g")
    done

    ((${#missing[@]})) || return 0
    ask "Ajouter $USER au groupe ${missing[*]} (temps réel pour l'audio) ?" || return 0

    for g in "${missing[@]}"; do
        sudo usermod -aG "$g" "$USER" || fail "  échec de l'ajout au groupe $g"
    done

    info "Pris en compte à la prochaine connexion (vérifier: ulimit -r)."
}
