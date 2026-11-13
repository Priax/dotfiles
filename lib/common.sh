# shellcheck shell=bash
# Fonctions de base: messages, questions, lecture du manifest, accès aux fichiers.
# Sourcé par dot, qui définit REPO_DIR, MANIFEST, BACKUP_DIR, EXCLUDES, OS et PKG_DIR.

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
DIM=$'\033[2m'
NC=$'\033[0m'

info() { printf '%s\n' "${YELLOW}$*${NC}"; }
ok() { printf '%s\n' "${GREEN}$*${NC}"; }
warn() { printf '%s\n' "${RED}$*${NC}" >&2; }

# Pour une étape qui échoue sans arrêter la commande. main rappelle ces échecs à la fin et
# sort en erreur, pour que « dot upgrade && dot push » s'arrête.
FAILURES=()
fail() {
    warn "$*"
    FAILURES+=("${1#"${1%%[! ]*}"}") # sans l'indentation du message
}
die() {
    warn "Erreur: $*"
    exit 1
}
have() { command -v "$1" &>/dev/null; }
ask() {
    local reply
    read -r -p "$1 (y/N) " reply
    [[ $reply =~ ^[YyOo]$ ]]
}

# Dossier du profil Firefox par défaut. Son nom est aléatoire (ex: 6mjqrltg.default-release),
# on le lit dans profiles.ini.
firefox_profile() {
    local roots root ini path
    if [[ $OS == macos ]]; then
        roots=("$HOME/Library/Application Support/Firefox")
    else
        roots=("$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox")
    fi
    for root in "${roots[@]}"; do
        ini="$root/profiles.ini"
        [[ -f $ini ]] || continue
        # D'abord le Default= de la section [Install…]: c'est le profil que Firefox ouvre vraiment
        path="$(awk -F= '/^\[/ {s = $0} s ~ /^\[Install/ && $1 == "Default" {print $2; exit}' "$ini")"
        if [[ -z $path ]]; then
            path="$(awk -F= '/^\[/ {s = $0; p = ""; d = 0}
                s ~ /^\[Profile/ { if ($1 == "Path") p = $2; if ($1 == "Default" && $2 == 1) d = 1
                                   if (p != "" && d) {print p; exit} }' "$ini")"
        fi
        [[ -z $path ]] && continue
        [[ $path == /* ]] || path="$root/$path"
        if [[ -d $path ]]; then
            echo "$path"
            return
        fi
    done
    return 1
}

# Lit le manifest et sort une ligne « chemin_machine<TAB>chemin_repo » par entrée
# (la syntaxe est décrite en tête du manifest).
entries() {
    local line tag src ff="" ff_done=0
    while IFS= read -r line || [[ -n $line ]]; do
        tag=""
        [[ $line == *"#"* ]] && tag="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"${line#*#}")"
        [[ ($tag == linux || $tag == macos) && $tag != "$OS" ]] && continue
        line="${line%%#*}"
        line="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$line")"
        [[ -z $line ]] && continue
        src=$line
        if [[ $line == *" < "* ]]; then
            src="$(sed 's/^[[:space:]]*//' <<<"${line#* < }")"
            line="$(sed 's/[[:space:]]*$//' <<<"${line%% < *}")"
        fi
        case $src in
            "~/"*) src="$REPO_DIR/home/${src#\~/}" ;;
            /*) src="$REPO_DIR/system$src" ;;
        esac
        case $line in
            "~/"*) printf '%s\t%s\n' "$HOME/${line#\~/}" "$src" ;;
            /*) printf '%s\t%s\n' "$line" "$src" ;;
            firefox:*)
                if ((!ff_done)); then
                    ff_done=1
                    ff="$(firefox_profile)" ||
                        warn "Profil Firefox introuvable, entrées firefox: ignorées (lance Firefox une fois, ferme-le, puis « dot apply »)"
                fi
                [[ -n $ff ]] && printf '%s\t%s\n' "$ff/${line#firefox:}" "$REPO_DIR/firefox/${line#firefox:}"
                ;;
            *) warn "Entrée ignorée (doit commencer par ~/, / ou firefox:): $line" ;;
        esac
    done <"$MANIFEST"
}

pretty() { sed "s|^$HOME|~|" <<<"$1"; }

is_home() { [[ $1 == "$HOME"/* ]]; }

# Hors de ~, les fichiers peuvent demander sudo (/etc, /var/lib/pgsql…)
read_file() {
    cat "$1" 2>/dev/null && return
    is_home "$1" && return 1
    sudo cat "$1" 2>/dev/null
}

sys_exists() {
    [[ -e $1 ]] && return
    is_home "$1" && return 1
    sudo test -e "$1" 2>/dev/null
}

# EXCLUDES sous la forme attendue par rsync et par diff
RSYNC_EXCLUDES=()
DIFF_EXCLUDES=()
for e in "${EXCLUDES[@]}"; do
    RSYNC_EXCLUDES+=("--exclude=$e")
    DIFF_EXCLUDES+=(-x "$e")
done
unset e
