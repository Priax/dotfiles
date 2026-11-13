# shellcheck shell=bash
# Entretien de la config nvim en headless, par lib/nvim_maint.lua
#
#   nvim_maint install         plugins aux versions de lazy-lock.json, parsers et paquets Mason manquants
#   nvim_maint upgrade         plugins (lazy sync), ce qui manque, puis mise à jour de tout
#   nvim_maint list <fichier>  retire les plugins sortis de la config (lazy clean), puis écrit dans
#                              <fichier> les parsers et paquets Mason qu'elle n'utilise plus
#   nvim_maint remove <fichier>  désinstalle ce que contient <fichier> (après confirmation, dot clean)
nvim_maint() {
    have nvim || return 0
    # On filtre le détail des tâches git de lazy (une dizaine de lignes par plugin). Les erreurs
    # et les messages du script restent.
    DOT_NVIM=$1 DOT_NVIM_LIST=${2:-} nvim --headless -c "luafile $REPO_DIR/lib/nvim_maint.lua" 2>&1 |
        { grep -vE '(Running|Finished) task|Récupération du sous-module|Fetching submodule|HEAD est maintenant sur|HEAD is now at' || true; } ||
        fail "  nvim: échec de l'entretien"
}
