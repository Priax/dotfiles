-- Chargé avant lazy.nvim. Les options par défaut de LazyVim:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt
local o = vim.o

-- indentation à 4 (LazyVim met 2)
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4

-- numéros absolus, <leader>uL pour basculer
o.relativenumber = false

-- repère à 80 colonnes (norme Epitech)
opt.colorcolumn = "80"

-- caractères invisibles
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- .mdx (blog): nvim ne connaît pas l'extension, on le colore comme du markdown
vim.filetype.add { extension = { mdx = "mdx" } }
vim.treesitter.language.register("markdown", "mdx")
