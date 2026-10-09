local options = {
    formatters = {
        biome = {
            condition = function(_, ctx)
                return vim.fs.find("biome.json", {
                    upward = true,
                    path = ctx.filename,
                })[1] ~= nil
            end,
        },
    },
    formatters_by_ft = {
        lua = { "stylua" },
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
        go = { "goimports", "gofmt" },
    },

    format_on_save = {
        -- These options will be passed to conform.format()
        timeout_ms = 500,
        lsp_fallback = true,
    },
}

return options
