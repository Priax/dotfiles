require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd

autocmd("FileType", {
    pattern = "*",
    callback = function()
        -- j: retire le commentaire si la ligne devient vide après un join
        -- o: retire l'auto-commentaire après 'o' ou 'O'
        -- r: retire l'auto-commentaire après <Enter> en mode insertion
        vim.opt_local.formatoptions:remove { "r", "o", "j" }

        if vim.bo.buftype == "" then
            vim.opt_local.foldmethod = "expr"
            vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end
    end,
})

require "configs.video_preview"
