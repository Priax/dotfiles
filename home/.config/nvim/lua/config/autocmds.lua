-- Chargé après les autocmds de LazyVim (groupes préfixés par `lazyvim_`):
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- LazyVim active wrap + spell (anglais) dans les fichiers texte: on ne garde que wrap
autocmd("FileType", {
    group = augroup("lazyvim_wrap_spell", { clear = true }),
    pattern = { "text", "plaintex", "typst", "gitcommit", "markdown", "mdx" },
    callback = function()
        vim.opt_local.wrap = true
    end,
})

autocmd("FileType", {
    group = augroup("UserFileType", { clear = true }),
    pattern = "*",
    callback = function()
        -- j: retire le commentaire si la ligne devient vide après un join
        -- o: retire l'auto-commentaire après 'o' ou 'O'
        -- r: retire l'auto-commentaire après <Enter> en mode insertion
        vim.opt_local.formatoptions:remove { "r", "o", "j" }
    end,
})

-- .mdx / .md: pas de ' auto-fermant (apostrophes du français).
-- Le mapping local au buffer passe avant celui, global, de mini.pairs
autocmd("FileType", {
    group = augroup("UserNoQuotePair", { clear = true }),
    pattern = { "mdx", "markdown" },
    callback = function(args)
        vim.keymap.set("i", "'", "'", { buffer = args.buf })
    end,
})

-- MDX: champs fantômes des props (mdx_props) et fermeture automatique des balises (mdx_autoclose)
autocmd("FileType", {
    group = augroup("UserMdx", { clear = true }),
    pattern = "mdx",
    callback = function(args)
        require("configs.mdx_props").attach(args.buf)
        require("configs.mdx_autoclose").attach(args.buf)
    end,
})

-- Les fenêtres flottantes de nvim-dap (<leader>dw…) prennent le focus sans moyen de les fermer:
-- q / <Esc> les ferment, et elles se ferment seules quand on en sort
autocmd("FileType", {
    group = augroup("DapFloat", { clear = true }),
    pattern = "dap-float",
    callback = function(args)
        local win = vim.api.nvim_get_current_win()
        local function close()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end
        vim.keymap.set("n", "q", close, { buffer = args.buf, desc = "Fermer" })
        vim.keymap.set("n", "<Esc>", close, { buffer = args.buf, desc = "Fermer" })
        autocmd("WinLeave", { buffer = args.buf, once = true, callback = close })
    end,
})

vim.api.nvim_create_user_command("MasonInstallAll", function()
    vim.cmd "Mason"
    require("configs.mason").install_all()
end, { desc = "Installer les paquets Mason de la config (LSP, formatters, DAP)" })

require "configs.video_preview"
require("configs.colorscheme").setup()
