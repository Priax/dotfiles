require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- I ADDED THIS
map("n", "<leader>q", function()
    vim.diagnostic.setqflist()
    vim.cmd "copen"
end, { desc = "Diagnostics to quickfix" })

map("n", "<leader>o", function()
    local file = vim.fn.expand "%:p"
    if file ~= "" then
        vim.ui.open(file)
        print("Fichier ouvert : " .. file)
    else
        print "Aucun fichier à ouvrir"
    end
end, { desc = "Ouvrir le fichier avec l'application système" })

map("n", "<leader>;", ";", { desc = "Repeat find forward" })

map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP Code Action" })

-- debugger mappings
map("n", "<leader>dd", function()
    require("dap").run(require("dap").configurations.cpp[1])
end, { desc = "Debug Launch (C/C++)" })

map("n", "<leader>dR", function()
    require("dap").run(require("dap").configurations.rust[1])
end, { desc = "Debug Launch (Rust)" })

map("n", "<leader>db", function()
    require("dap").toggle_breakpoint()
end, { desc = "Toggle Breakpoint" })

map("n", "<leader>dP", function()
    require("dap").pause()
end, { desc = "Pause Debugging" })

map("n", "<leader>dr", function()
    require("dap").repl.open()
end, { desc = "Open DAP REPL" })

map("n", "<leader>dh", function()
    require("dap.ui.widgets").hover()
end, { desc = "Inspect Variable Under Cursor" })

map("n", "<leader>dc", function()
    require("dap").continue()
end, { desc = "Start/Continue Debugging" })

map("n", "<leader>di", function()
    require("dap").step_into()
end, { desc = "Step Into" })

map("n", "<leader>do", function()
    require("dap").step_over()
end, { desc = "Step Over" })

map("n", "<leader>dO", function()
    require("dap").step_out()
end, { desc = "Step Out" })

map("n", "<leader>du", function()
    require("dapui").toggle()
end, { desc = "Toggle DAP UI" })

map("n", "<leader>dl", function()
    require("dap").run_last()
end, { desc = "Run Last Debug Session" })

map("n", "<leader>dq", function()
    require("dap").terminate()
end, { desc = "Terminate Debugging" })

map("n", "<leader>hh", "<cmd>Hoogle<cr>", { desc = "Hoogle search" })
