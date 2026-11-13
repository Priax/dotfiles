-- La liste des paquets Mason de la config. LazyVim installe déjà ce qui manque au démarrage;
-- ce module sert à :checkhealth configs et à dot (clean, et install / pull, qui doivent
-- attendre la fin des installations).

local M = {}

-- ensure_installed de mason.nvim, plus les LSP activés dans nvim-lspconfig que Mason sait installer
function M.wanted()
    require("lazy").load { plugins = { "mason.nvim", "nvim-lspconfig" } }
    local wanted, seen = {}, {}
    local function add(name)
        if not seen[name] then
            seen[name] = true
            wanted[#wanted + 1] = name
        end
    end
    for _, name in ipairs(LazyVim.opts("mason.nvim").ensure_installed or {}) do
        add(name)
    end
    local packages = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
    for server, opts in pairs(LazyVim.opts("nvim-lspconfig").servers or {}) do
        local enabled = opts == true or (type(opts) == "table" and opts.enabled ~= false and opts.mason ~= false)
        if enabled and packages[server] then
            add(packages[server])
        end
    end
    table.sort(wanted)
    return wanted
end

-- Installe ce qui manque. on_start(nom) est appelé à chaque installation, on_done(échecs) à la fin.
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
                local function done(success, err)
                    if not success then
                        failed[#failed + 1] = name .. ": " .. tostring(err)
                    end
                    pending = pending - 1
                    finish()
                end
                if pkg:is_installing() then
                    -- LazyVim l'a déjà lancée, on attend la fin
                    pkg:once("install:success", function()
                        done(true)
                    end)
                    pkg:once("install:failed", function(err)
                        done(false, err)
                    end)
                else
                    pkg:install({ version = version ~= "" and version or nil }, done)
                end
            end
        end
        finish()
    end)
end

return M
