-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
    theme = "decay",

    -- hl_override = {
    --     Comment = { italic = true },
    --     ["@comment"] = { italic = true },
    -- },
}

-- :MasonInstallAll (redéfini dans configs/mason.lua) installe déjà les LSP de lspconfig.lua et
-- les formatters de conform.lua: ici, seulement ce que rien ne déclare (go requis pour delve)
M.mason = {
    pkgs = { "codelldb", "delve" }, -- adaptateurs DAP (configs/dap.lua, nvim-dap-go)
    skip = { "rust-analyzer" }, -- fourni par rustup
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
