-- Chargé après les autocmds de LazyVim (groupes en `lazyvim_`):
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- LazyVim active wrap et spell (en anglais) dans les fichiers texte. On garde seulement wrap,
-- en réutilisant le nom de son groupe pour remplacer son autocmd.
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
        -- pas de commentaire prolongé automatiquement par <Entrée> (r) ni par o / O (o)
        vim.opt_local.formatoptions:remove { "r", "o" }
    end,
})

-- Markdown et MDX: ' ne se ferme pas tout seul, à cause des apostrophes du français.
-- Un mapping local au buffer passe avant celui de mini.pairs.
autocmd("FileType", {
    group = augroup("UserNoQuotePair", { clear = true }),
    pattern = { "mdx", "markdown" },
    callback = function(args)
        vim.keymap.set("i", "'", "'", { buffer = args.buf })
    end,
})

-- MDX: props proposées en texte fantôme et balises fermées automatiquement
autocmd("FileType", {
    group = augroup("UserMdx", { clear = true }),
    pattern = "mdx",
    callback = function(args)
        require("configs.mdx_props").attach(args.buf)
        require("configs.mdx_autoclose").attach(args.buf)
    end,
})

-- Les fenêtres flottantes de nvim-dap (<leader>dw…) prennent le focus et rien ne les ferme.
-- Ici, q et <Esc> les ferment, et elles se ferment aussi quand on en sort.
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
