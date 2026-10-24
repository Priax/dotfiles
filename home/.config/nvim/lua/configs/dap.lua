local dap = require "dap"
local dapui = require "dapui"
local utils = require "dap.utils"

-- découpe en respectant les guillemets ("a b" reste un seul argument)
local function ask_args()
    return utils.splitstr(vim.fn.input "Program arguments: ")
end

local codelldb_path = vim.fn.stdpath "data" .. "/mason/bin/codelldb"

dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = codelldb_path,
        args = { "--port", "${port}" },
        detached = false,
    },
}

dap.configurations.c = {
    {
        name = "Launch (CodeLLDB)",
        type = "codelldb",
        request = "launch",
        program = function()
            return utils.pick_file { executables = true }
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = ask_args,
    },
    {
        name = "Attach to process",
        type = "codelldb",
        request = "attach",
        pid = function()
            local name = vim.fn.input "Executable name (filter): "
            return utils.pick_process { filter = name }
        end,
        cwd = "${workspaceFolder}",
    },
}

dap.configurations.rust = {
    {
        name = "Launch Rust (CodeLLDB)",
        type = "codelldb",
        request = "launch",
        program = function()
            -- pas de pick_file ici: target/debug/deps est plein de binaires de test
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = ask_args,
    },
    {
        name = "Attach Rust process",
        type = "codelldb",
        request = "attach",
        pid = function()
            local name = vim.fn.input "Executable name (filter): "
            return utils.pick_process { filter = name }
        end,
        cwd = "${workspaceFolder}",
    },
}

dap.configurations.cpp = dap.configurations.c

dapui.setup()

dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
end

-- Les fenêtres flottantes de nvim-dap (survol <leader>dh…) prennent le focus sans moyen de les fermer:
-- q / <Esc> les ferment, et elles se ferment seules quand on en sort
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("DapFloat", { clear = true }),
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
        vim.api.nvim_create_autocmd("WinLeave", { buffer = args.buf, once = true, callback = close })
    end,
})
