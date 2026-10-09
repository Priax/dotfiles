local dap = require "dap"
local dapui = require "dapui"

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
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = function()
            local input = vim.fn.input "Program arguments: "
            if input == "" then
                return {}
            end
            return vim.split(input, " ")
        end,
    },
    {
        name = "Attach to process",
        type = "codelldb",
        request = "attach",
        pid = function()
            local name = vim.fn.input "Executable name (filter): "
            return require("dap.utils").pick_process { filter = name }
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
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = function()
            local input = vim.fn.input "Program arguments: "
            if input == "" then
                return {}
            end
            return vim.split(input, " ")
        end,
    },
    {
        name = "Attach Rust process",
        type = "codelldb",
        request = "attach",
        pid = function()
            local name = vim.fn.input "Executable name (filter): "
            return require("dap.utils").pick_process { filter = name }
        end,
        cwd = "${workspaceFolder}",
    },
}

dap.configurations.cpp = dap.configurations.c

dapui.setup()

dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
end
