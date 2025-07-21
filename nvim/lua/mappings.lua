require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- I ADDED THIS
map("n", "<leader>q", function()
  vim.diagnostic.setqflist()
  vim.cmd("copen")
end, { desc = "Diagnostics to quickfix" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
