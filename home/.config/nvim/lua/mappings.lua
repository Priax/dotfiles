require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>", { desc = "Quitter le mode insertion" })

map("n", "<leader>q", function()
    vim.diagnostic.setqflist()
    vim.cmd "copen"
end, { desc = "Diagnostics to quickfix" })

map("n", "<leader>o", function()
    -- NvimTree, Telescope, terminal…: le nom du buffer n'est pas un fichier (ex: NvimTree_1)
    local file = vim.fn.expand "%:p"
    if vim.bo.filetype == "NvimTree" then
        local node = require("nvim-tree.api").tree.get_node_under_cursor()
        file = node and node.absolute_path or ""
    elseif vim.bo.buftype ~= "" then
        file = ""
    end
    if file ~= "" and vim.uv.fs_stat(file) then
        vim.ui.open(file)
        vim.notify("Fichier ouvert: " .. file)
    else
        vim.notify("Aucun fichier à ouvrir", vim.log.levels.WARN)
    end
end, { desc = "Ouvrir le fichier avec l'application système" })

map("n", "<leader>;", ";", { desc = "Repeat find forward" })

-- debugger mappings
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
    -- sans session, le survol de nvim-dap ouvre une fenêtre vide « No active session »
    if not require("dap").session() then
        return vim.notify("Pas de session de debug active", vim.log.levels.WARN)
    end
    require("dap.ui.widgets").hover()
end, { desc = "Inspect Variable Under Cursor" })

map("n", "<leader>dc", function()
    require("dap").continue()
end, { desc = "Start/Continue Debugging (choix de la config selon le filetype)" })

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

-- LSP dans Telescope (remplace les grr/gri/grt/gO natifs de Neovim)
map("n", "grr", function()
    require("telescope.builtin").lsp_references()
end, { desc = "LSP References (Telescope)" })

map("n", "gri", function()
    require("telescope.builtin").lsp_implementations()
end, { desc = "LSP Implementations (Telescope)" })

map("n", "grt", function()
    require("telescope.builtin").lsp_type_definitions()
end, { desc = "LSP Type Definitions (Telescope)" })

map("n", "gO", function()
    require("telescope.builtin").lsp_document_symbols()
end, { desc = "LSP Document Symbols (Telescope)" })
