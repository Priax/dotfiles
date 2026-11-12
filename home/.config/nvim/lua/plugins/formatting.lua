-- Formatage à la sauvegarde: géré par LazyVim (vim.g.autoformat, <leader>uf pour basculer,
-- <leader>cf pour formater), avec repli sur le LSP quand aucun formatter n'est déclaré
return {
    {
        "stevearc/conform.nvim",
        -- fonction et pas table: lazy.nvim fusionnerait les listes index par index
        -- (go = { "goimports", "gofumpt" } de l'extra garderait gofumpt)
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
