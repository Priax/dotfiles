# .gdbinit des projets chargés automatiquement seulement sous ~/delivery (« / » autorisait n'importe
# quel dossier: un dépôt cloné pouvait exécuter des commandes au lancement de gdb).
# $debugdir et $datadir/auto-load: valeurs par défaut, pour les pretty-printers (libstdc++, glib…).
set auto-load safe-path $debugdir:$datadir/auto-load:~/delivery
