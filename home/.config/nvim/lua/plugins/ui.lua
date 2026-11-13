return {
    -- Même thème que kitty, avec les fonds du thème decay de NvChad. Le fond de Catppuccin
    -- Mocha (#1e1e2e) est exactement celui de kitty, qui rend alors ces cases transparentes
    -- (background_opacity 0.70): on voyait le fond d'écran à travers nvim.
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
    -- Le dernier thème choisi est repris au démarrage (configs/colorscheme.lua). Par défaut,
    -- « catppuccin-nvim » et pas « catppuccin »: Neovim 0.12 a son propre catppuccin.vim, qui
    -- passerait avant celui du plugin, sans ses réglages ni ses intégrations.
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = function()
                require("configs.colorscheme").load()
            end,
        },
    },

    -- Sur K, noice traite chaque serveur LSP à part et affiche « No information available »
    -- pour chacun de ceux qui n'ont rien à dire (astro, render-markdown à côté de
    -- mdx_analyzer…), même quand un autre a affiché la doc.
    { "folke/noice.nvim", opts = { lsp = { hover = { silent = true } } } },

    -- accueil sans le logo LazyVim
    {
        "folke/snacks.nvim",
        opts = {
            dashboard = {
                sections = {
                    { section = "keys", gap = 1, padding = 1 },
                    { section = "startup" },
                },
            },
            -- arbre de fichiers plus étroit (40 colonnes par défaut)
            picker = { sources = { explorer = { layout = { layout = { width = 25 } } } } },
            -- les touches qui ouvrent un terminal (config/keymaps.lua) le cachent
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
