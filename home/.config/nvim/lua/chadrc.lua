-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
    theme = "decay",

    -- hl_override = {
    -- 	Comment = { italic = true },
    -- 	["@comment"] = { italic = true },
    -- },
}

-- installés par :MasonInstallAll (go requis pour gopls, goimports et delve)
M.mason = {
    pkgs = {
        "astro-language-server",
        "biome",
        "clangd",
        "clang-format",
        "codelldb",
        "css-lsp",
        "delve",
        "eslint-lsp",
        "fourmolu",
        "goimports",
        "gopls",
        "html-lsp",
        "lua-language-server",
        "mdx-analyzer",
        "prettier",
        "rust-analyzer",
        "stylua",
        "typescript-language-server",
    },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
