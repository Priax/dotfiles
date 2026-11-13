-- Lancé par nvim_maint (lib/nvim.sh) dans nvim --headless.
-- DOT_NVIM: install, upgrade, list ou remove. DOT_NVIM_LIST: fichier de la liste (list, remove).

local mode = vim.env.DOT_NVIM
local function say(m)
    io.stdout:write("  " .. m .. "\n")
    io.stdout:flush()
end

-- Un échec est affiché tout de suite, et nvim sort en erreur à la fin (cq)
local had_error = false
local function report(m)
    had_error = true
    say(m)
end

-- lazy ne lève pas d'erreur, l'échec d'un git fetch reste noté sur le plugin
local function check_plugins()
    local Plugin = require "lazy.core.plugin"
    for name, plugin in pairs(require("lazy.core.config").plugins) do
        if Plugin.has_errors(plugin) then
            report("échec du plugin " .. name)
        end
    end
end

local function mason_ready()
    local mr = require "mason-registry"
    local refreshed = false
    mr.refresh(function()
        refreshed = true
    end)
    vim.wait(120000, function()
        return refreshed
    end, 200)
    return mr
end

-- ensure_installed et leurs dépendances (javascript → ecma, jsx; html → html_tags…)
local function wanted_parsers()
    local spec = require("lazy.core.config").plugins["nvim-treesitter"]
    local parsers, wanted = require "nvim-treesitter.parsers", {}
    local function want(lang)
        if wanted[lang] then
            return
        end
        wanted[lang] = true
        for _, dep in ipairs(parsers[lang] and parsers[lang].requires or {}) do
            want(dep)
        end
    end
    for _, lang in ipairs(require("lazy.core.plugin").values(spec, "opts", false).ensure_installed or {}) do
        want(lang)
    end
    return wanted
end

-- Ceux de configs/mason.lua, plus tout paquet qui fournit un LSP activé (au cas où un LSP serait
-- activé ailleurs que dans les opts de nvim-lspconfig)
local function wanted_mason(mr)
    local keep = {}
    for _, name in ipairs(require("configs.mason").wanted()) do
        keep[name:match "^[^@]+"] = true
    end
    local enabled = vim.lsp._enabled_configs or {}
    for _, pkg in ipairs(mr.get_installed_packages()) do
        local lsp = pkg.spec.neovim and pkg.spec.neovim.lspconfig
        if lsp and enabled[lsp] then
            keep[pkg.name] = true
        end
    end
    return keep
end

local function run_all(jobs)
    local pending = #jobs
    for _, job in ipairs(jobs) do
        job(function(success, err)
            if not success then
                report("échec: " .. tostring(err))
            end
            pending = pending - 1
        end)
    end
    if not vim.wait(1800000, function()
        return pending == 0
    end, 500) then
        report "paquets Mason: délai dépassé"
    end
end

-- xpcall pour quitter même en cas d'erreur, sinon nvim headless reste ouvert
local ok, err = xpcall(function()
    local lazy = require "lazy"
    if mode == "install" then
        say "plugins (lazy-lock.json)..."
        lazy.restore { wait = true, show = false }
    elseif mode == "upgrade" then
        say "plugins (lazy sync)..."
        lazy.sync { wait = true, show = false }
    elseif mode == "list" then
        say "plugins retirés de la config (lazy clean)..."
        lazy.clean { wait = true, show = false }
    end
    check_plugins()
    lazy.load { plugins = { "nvim-lspconfig", "conform.nvim", "mason.nvim", "nvim-treesitter" } }
    local ts = require "nvim-treesitter"
    local mr = mason_ready()

    if mode == "install" or mode == "upgrade" then
        -- LazyVim installe aussi les parsers manquants au démarrage, mais sans attendre la fin.
        -- install() ajoute lui-même les dépendances.
        local spec = require("lazy.core.config").plugins["nvim-treesitter"]
        local installed = ts.get_installed()
        local missing = vim.tbl_filter(function(lang)
            return not vim.tbl_contains(installed, lang)
        end, require("lazy.core.plugin").values(spec, "opts", false).ensure_installed or {})
        if #missing > 0 then
            say("parsers treesitter manquants: " .. table.concat(missing, ", "))
            local installed_all = ts.install(missing):wait(900000)
            io.stdout:write "\n" -- nvim-treesitter ne termine pas ses messages par un retour à la ligne
            if not installed_all then
                report "échec de l'installation de parsers treesitter"
            end
        end
        local failed, started = nil, 0
        require("configs.mason").install_all(function(f)
            failed = f
        end, function(name)
            started = started + 1
            say("Mason: installation de " .. name)
        end)
        if not vim.wait(1800000, function()
            return failed ~= nil
        end, 500) then
            report "paquets Mason: délai dépassé"
        end
        for _, line in ipairs(failed or {}) do
            report("échec Mason " .. line)
        end
        if #missing == 0 and started == 0 then
            say "parsers et paquets Mason: rien ne manque"
        end
    end
    if mode == "upgrade" then
        say "mise à jour des parsers treesitter..."
        if not ts.update():wait(600000) then
            report "échec de la mise à jour de parsers treesitter"
        end
        local jobs = {}
        for _, pkg in ipairs(mr.get_installed_packages()) do
            local current, latest = pkg:get_installed_version(), pkg:get_latest_version()
            if current ~= latest then
                say(("Mason %s: %s → %s"):format(pkg.name, current or "?", latest))
                jobs[#jobs + 1] = function(done)
                    pkg:install({}, done)
                end
            end
        end
        run_all(jobs)
    elseif mode == "list" then
        local lines, parsers, keep = {}, wanted_parsers(), wanted_mason(mr)
        for _, lang in ipairs(ts.get_installed()) do
            if not parsers[lang] then
                lines[#lines + 1] = "parser " .. lang
            end
        end
        for _, pkg in ipairs(mr.get_installed_packages()) do
            if not keep[pkg.name] then
                lines[#lines + 1] = "mason " .. pkg.name
            end
        end
        vim.fn.writefile(lines, vim.env.DOT_NVIM_LIST)
    elseif mode == "remove" then
        local langs, jobs = {}, {}
        for _, line in ipairs(vim.fn.readfile(vim.env.DOT_NVIM_LIST)) do
            local kind, name = line:match "^(%S+) (%S+)$"
            if kind == "parser" then
                langs[#langs + 1] = name
            elseif kind == "mason" and mr.is_installed(name) then
                jobs[#jobs + 1] = function(done)
                    mr.get_package(name):uninstall({}, done)
                end
            end
        end
        if #langs > 0 then
            ts.uninstall(langs):wait(60000)
        end
        run_all(jobs)
    end
end, debug.traceback)
if not ok then
    report("erreur: " .. err)
end
vim.cmd(had_error and "cq" or "qa!")
