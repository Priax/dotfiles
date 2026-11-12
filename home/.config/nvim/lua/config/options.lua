-- Chargé avant lazy.nvim. Options par défaut de LazyVim:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt
local o = vim.o

-- Indentation à 4 au lieu de 2
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4

-- Numéros de ligne absolus (<leader>uL pour basculer)
o.relativenumber = false

-- ligne affichée sur la colonne du dernier caractère voulu
opt.colorcolumn = "69"

-- show invisible caracters
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- .mdx (blog): nvim ne connaît pas l'extension, coloration markdown
vim.filetype.add { extension = { mdx = "mdx" } }
vim.treesitter.language.register("markdown", "mdx")
