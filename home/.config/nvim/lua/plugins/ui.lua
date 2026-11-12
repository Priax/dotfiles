return {
    -- Même thème que kitty (current-theme.conf), mais avec les fonds du thème decay de NvChad.
    -- Le fond de Catppuccin Mocha (#1e1e2e) est exactement celui de kitty, qui rend alors ces
    -- cellules transparentes (background_opacity 0.70): le fond d'écran passait à travers nvim
    {
        "catppuccin/nvim",
        name = "catppuccin",
        opts = {
            flavour = "mocha",
            color_overrides = {
                mocha = {
                    base = "#171B20", -- fond du code
                    mantle = "#111519", -- arbre, barre d'état, fenêtres flottantes
                    crust = "#0D1014",
                },
            },
        },
    },
    -- « catppuccin-nvim » et pas « catppuccin »: Neovim 0.12 embarque son propre catppuccin.vim,
    -- qui passe avant celui du plugin (sans ses réglages ni ses intégrations)
    { "LazyVim/LazyVim", opts = { colorscheme = "catppuccin-nvim" } },

    -- K: noice traite la réponse de chaque serveur LSP à part, et notifie « No information
    -- available » pour chacun de ceux qui n'ont rien à dire (astro, render-markdown à côté
    -- de mdx_analyzer…), même quand un autre a affiché la doc
    { "folke/noice.nvim", opts = { lsp = { hover = { silent = true } } } },

    -- Écran d'accueil sans le logo LazyVim: le menu et le temps de démarrage seulement
    {
        "folke/snacks.nvim",
        opts = {
            dashboard = {
                sections = {
                    { section = "keys", gap = 1, padding = 1 },
                    { section = "startup" },
                },
            },
            -- Largeur de l'arbre de fichiers, en colonnes (40 par défaut)
            picker = { sources = { explorer = { layout = { layout = { width = 25 } } } } },
            -- cacher le terminal avec les touches qui l'ouvrent (config/keymaps.lua)
            terminal = {
                win = {
                    keys = {
                        hide_alt_h = { "<A-h>", "hide", desc = "Cacher le terminal", mode = "t" },
                        hide_alt_v = { "<A-v>", "hide", desc = "Cacher le terminal", mode = "t" },
                        hide_alt_i = { "<A-i>", "hide", desc = "Cacher le terminal", mode = "t" },
                    },
                },
            },
        },
    },
}
