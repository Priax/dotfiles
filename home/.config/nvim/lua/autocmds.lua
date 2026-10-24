require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd

autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserFileType", { clear = true }),
    pattern = "*",
    callback = function(args)
        -- j: retire le commentaire si la ligne devient vide après un join
        -- o: retire l'auto-commentaire après 'o' ou 'O'
        -- r: retire l'auto-commentaire après <Enter> en mode insertion
        vim.opt_local.formatoptions:remove { "r", "o", "j" }

        -- nvchad.autocmds fait déjà vim.treesitter.start: ici, seulement vérifier qu'il a marché
        if vim.bo[args.buf].buftype == "" and vim.treesitter.highlighter.active[args.buf] then
            local win = vim.fn.bufwinid(args.buf)
            if win ~= -1 then
                vim.wo[win][0].foldmethod = "expr"
                vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
            end
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

-- MDX: champs fantômes des props (mdx_props) et fermeture automatique des balises (mdx_autoclose)
autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserMdx", { clear = true }),
    pattern = "mdx",
    callback = function(args)
        require("configs.mdx_props").attach(args.buf)
        require("configs.mdx_autoclose").attach(args.buf)
    end,
})

require "configs.video_preview"
require "configs.mason"
