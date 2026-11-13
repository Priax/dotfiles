-- Thème persistant: le dernier thème appliqué (<leader>uC, :colorscheme, :set bg=…) est repris
-- au prochain démarrage. Nom et fond (dark / light) dans un fichier de stdpath("state")

local M = {}

local default = "catppuccin-nvim"
local file = vim.fn.stdpath "state" .. "/colorscheme"

function M.load()
    local ok, lines = pcall(vim.fn.readfile, file)
    local name = ok and lines[1] or default
    if ok and (lines[2] == "dark" or lines[2] == "light") then
        vim.o.background = lines[2]
    end
    -- thème désinstallé ou cassé: on retombe sur celui par défaut
    if not pcall(vim.cmd.colorscheme, name) then
        vim.o.background = "dark"
        vim.cmd.colorscheme(default)
    end
end

function M.setup()
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("UserColorschemePersist", { clear = true }),
        callback = function(args)
            -- args.match: le nom passé à :colorscheme (g:colors_name peut différer)
            pcall(vim.fn.writefile, { args.match, vim.o.background }, file)
        end,
    })
end

return M
