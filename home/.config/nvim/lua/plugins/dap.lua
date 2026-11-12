-- nvim-dap, dap-ui, les raccourcis <leader>d… et les adaptateurs (codelldb, delve) viennent des
-- extras dap.core, lang.clangd, lang.rust (rustaceanvim: <leader>dr) et lang.go (nvim-dap-go)
return {
    {
        "mfussenegger/nvim-dap",
        -- après l'extra lang.clangd, qui demande le chemin de l'exécutable à la main
        opts = function()
            local dap = require "dap"
            local utils = require "dap.utils"

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
                    -- découpe en respectant les guillemets ("a b" reste un seul argument)
                    args = function()
                        return utils.splitstr(vim.fn.input "Program arguments: ")
                    end,
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
            dap.configurations.cpp = dap.configurations.c
        end,
    },
}
