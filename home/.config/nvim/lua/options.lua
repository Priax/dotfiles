-- Options par défaut de NvChad (:NvChadOptions pour voir le fichier à jour):
-- laststatus=3, showmode=false, splitkeep=screen, clipboard=unnamedplus,
-- cursorline + cursorlineopt=number, expandtab, smartindent, shiftwidth/tabstop/softtabstop=2,
-- fillchars eob=" ", ignorecase + smartcase, mouse=a, number, numberwidth=2, ruler=false,
-- shortmess+=sI, signcolumn=yes, splitbelow, splitright, timeoutlen=400, undofile,
-- updatetime=250, whichwrap+=<>[]hl, providers node/python3/perl/ruby désactivés,
-- mason/bin ajouté au PATH
require "nvchad.options"

vim.api.nvim_create_user_command("NvChadOptions", function()
    vim.cmd.sview(vim.api.nvim_get_runtime_file("lua/nvchad/options.lua", false)[1])
end, { desc = "Afficher les options par défaut de NvChad" })

local opt = vim.opt
local o = vim.o

-- Indentation à 4 au lieu de 2
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4

-- ligne affichée sur la colonne du dernier caractère voulu
opt.colorcolumn = "69"

-- show invisible caracters
o.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- .mdx (blog): nvim ne connaît pas l'extension, coloration markdown
vim.filetype.add { extension = { mdx = "mdx" } }
vim.treesitter.language.register("markdown", "mdx")

-- zc pour plier, zo pour déplier
o.foldlevel = 99
o.foldlevelstart = 99
