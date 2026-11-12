return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- s'ajoute aux parsers de LazyVim et de ses extras (go, rust, clangd, typescript),
        -- installés au démarrage s'ils manquent
        opts = {
            ensure_installed = {
                "css",
                "haskell",
                "astro",
                "gitcommit",
            },
        },
    },
}
