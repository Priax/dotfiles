-- LazyVim formate à la sauvegarde (<leader>uf pour couper, <leader>cf à la main), et se rabat
-- sur le LSP quand aucun formatter n'est déclaré pour le langage.
return {
    {
        "stevearc/conform.nvim",
        -- une fonction plutôt qu'une table: lazy fusionnerait les listes élément par élément, et
        -- le go = { "goimports", "gofumpt" } de l'extra garderait gofumpt
        opts = function(_, opts)
            opts.formatters = opts.formatters or {}
            opts.formatters.biome = {
                condition = function(_, ctx)
                    return vim.fs.find({ "biome.json", "biome.jsonc" }, {
                        upward = true,
                        path = ctx.filename,
                    })[1] ~= nil
                end,
            }

            for ft, formatters in pairs {
                javascript = { "biome" },
                typescript = { "biome" },
                javascriptreact = { "biome" },
                typescriptreact = { "biome" },
                json = { "biome" },
                jsonc = { "biome" },
                css = { "prettier" },
                html = { "prettier" },
                c = { "clang-format" },
                cpp = { "clang-format" },
                haskell = { "fourmolu" },
                go = { "goimports" }, -- goimports applique déjà gofmt
            } do
                opts.formatters_by_ft[ft] = formatters
            end
        end,
    },
}
