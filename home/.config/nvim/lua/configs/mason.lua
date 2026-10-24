-- Paquets Mason: une seule source de vérité.
-- Le :MasonInstallAll de NvChad ne voit les LSP activés qu'une fois nvim-lspconfig chargé (event
-- « User FilePost », donc avec un fichier ouvert): lancé depuis un écran vide, comme sur une
-- machine neuve, il n'installait que les formatters. Ce qui déclare les paquets est donc chargé d'abord.

local M = {}

-- Paquets voulus: LSP activés (lspconfig.lua), formatters (conform.lua) et les pkgs de chadrc
-- pour ce que rien ne déclare (adaptateurs DAP), moins mason.skip
function M.wanted()
    require("lazy").load { plugins = { "nvim-lspconfig", "conform.nvim", "mason.nvim" } }
    return require("nvchad.mason").get_pkgs()
end

-- Installe ce qui manque. on_start(nom) à chaque installation lancée, on_done(échecs) quand tout
-- est fini (dot install et dot pull, en headless)
function M.install_all(on_done, on_start)
    local wanted = M.wanted()
    local mr = require "mason-registry"
    mr.refresh(function()
        local pending, failed = 0, {}
        local function finish()
            if pending == 0 and on_done then
                on_done(failed)
            end
        end
        for _, spec in ipairs(wanted) do
            local name, version = spec:match "^([^@]+)@?(.*)$"
            local ok, pkg = pcall(mr.get_package, name)
            if not ok then
                failed[#failed + 1] = name .. ": absent du registre Mason"
            elseif not pkg:is_installed() then
                if on_start then
                    on_start(name)
                end
                pending = pending + 1
                pkg:install({ version = version ~= "" and version or nil }, function(success, err)
                    if not success then
                        failed[#failed + 1] = name .. ": " .. tostring(err)
                    end
                    pending = pending - 1
                    finish()
                end)
            end
        end
        finish()
    end)
end

-- NvChad définit cette commande dans un vim.schedule (ui/lua/nvchad/init.lua), donc après cette config:
-- cette définition, mise en file plus tard (ordre FIFO), passe après et la remplace
vim.schedule(function()
    vim.api.nvim_create_user_command("MasonInstallAll", function()
        vim.cmd "Mason"
        M.install_all()
    end, { desc = "Installer les paquets Mason de la config (LSP, formatters, DAP)" })
end)

return M
