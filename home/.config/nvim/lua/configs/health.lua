-- :checkhealth configs: ce dont cette config a besoin hors de nvim, et ce qu'elle doit avoir
-- installé (paquets Mason, parsers). Les outils sont installés par « dot install »
-- (install_nvim_deps et install_tools): garder les deux listes en phase.

local M = {}
local health = vim.health
local is_mac = vim.fn.has "mac" == 1

-- { exécutable(s) (un seul suffit), à quoi il sert, manquant = erreur (true) ou avertissement }
local tools = {
    { { "git" }, "lazy.nvim, Mason", true },
    { { "curl" }, "Mason, nvim-treesitter, image.nvim", true },
    { { "unzip" }, "Mason (paquets en .zip)", true },
    { { "cc", "gcc", "clang" }, "compilation des parsers nvim-treesitter", true },
    { { "tree-sitter" }, "nvim-treesitter (branche main)", true },
    { { "npm" }, "paquets Mason npm (LSP web, prettier, mdx-analyzer)", true },
    { { "go" }, "paquets Mason go (gopls, goimports, delve)", true },
    { { "python3" }, "paquet Mason pypi (clang-format)", true },
    { { "rg" }, "Telescope live_grep" },
    { { "magick" }, "image.nvim" },
    { { "ffmpeg" }, "aperçu des vidéos (miniatures)" },
    { { "ffprobe" }, "aperçu des vidéos (infos)" },
    { is_mac and { "pbcopy" } or { "wl-copy", "xclip" }, "presse-papiers système (clipboard=unnamedplus)" },
    { { "rust-analyzer" }, "LSP Rust (rustup component add rust-analyzer)" },
    { { "haskell-language-server-wrapper" }, "haskell-tools (ghcup install hls)" },
    { { "cabal-fmt" }, "formatage des .cabal (haskell-tools)" },
}

local function check_tools()
    health.start "Outils externes"
    for _, tool in ipairs(tools) do
        local names, purpose, required = tool[1], tool[2], tool[3]
        local found
        for _, name in ipairs(names) do
            if vim.fn.executable(name) == 1 then
                found = name
                break
            end
        end
        local label = table.concat(names, " / ")
        if found then
            health.ok(("%s: %s"):format(found, purpose))
        elseif required then
            health.error(("%s introuvable: %s"):format(label, purpose), "dot install")
        else
            health.warn(("%s introuvable: %s"):format(label, purpose), "dot install")
        end
    end
    if not vim.env.KITTY_WINDOW_ID then
        health.warn "pas dans kitty: image.nvim (protocole d'images de kitty) n'affichera rien"
    end
end

local function check_mason()
    health.start "Paquets Mason (:MasonInstallAll)"
    local mr = require "mason-registry"
    local missing = {}
    for _, spec in ipairs(require("configs.mason").wanted()) do
        local name = spec:match "^[^@]+"
        if not mr.is_installed(name) then
            missing[#missing + 1] = name
        end
    end
    if #missing == 0 then
        health.ok "tous les paquets de la config sont installés"
    else
        health.error("manquants: " .. table.concat(missing, ", "), ":MasonInstallAll")
    end
end

local function check_parsers()
    health.start "Parsers treesitter (ensure_installed)"
    require("lazy").load { plugins = { "nvim-treesitter" } }
    local spec = require("lazy.core.config").plugins["nvim-treesitter"]
    local wanted = require("lazy.core.plugin").values(spec, "opts", false).ensure_installed or {}
    local installed = require("nvim-treesitter").get_installed()
    local missing = vim.tbl_filter(function(lang)
        return not vim.tbl_contains(installed, lang)
    end, wanted)
    if #missing == 0 then
        health.ok(("les %d parsers sont installés"):format(#wanted))
    else
        health.error("manquants: " .. table.concat(missing, ", "), ":TSInstallAll")
    end
end

function M.check()
    check_tools()
    check_mason()
    check_parsers()
end

return M
