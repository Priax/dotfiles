return {
    {
        "nvim-treesitter/nvim-treesitter",
        -- en plus de ceux de LazyVim et des extras, installés au démarrage s'ils manquent
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
