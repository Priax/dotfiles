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

-- MDX : le parseur MDX ne tolère pas un JSX incomplet, donc mdx-analyzer ne complète
-- un composant que si sa balise est fermée. On ferme `<Nom` en `<Nom />` dès la première lettre.
autocmd("FileType", {
    pattern = "mdx",
    callback = function(args)
        local buf = args.buf
        require("configs.mdx_props").attach(buf)

        autocmd("TextChangedI", {
            buffer = buf,
            callback = function()
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                local before = line:sub(1, col)
                if before:match "<%u$" and not before:match "%w<%u$" and line:sub(col + 1) == "" then
                    vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, { " />" })
                end
            end,
        })

        local function after_cursor()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            return vim.api.nvim_get_current_line():sub(col + 1)
        end

        -- `>` : composant avec enfants, on retire le ` />` ajouté
        vim.keymap.set("i", ">", function()
            local close = after_cursor():match "^ ?/>"
            return close and ("<Del>"):rep(#close) .. ">" or ">"
        end, { buffer = buf, expr = true })

        -- `/` : on saute par-dessus le ` />` existant
        vim.keymap.set("i", "/", function()
            local close = after_cursor():match "^ ?/>"
            return close and ("<Right>"):rep(#close) or "/"
        end, { buffer = buf, expr = true })

        -- espace juste après le nom : on réutilise celui du ` />`
        vim.keymap.set("i", "<Space>", function()
            return after_cursor():match "^ />" and "<Right>" or " "
        end, { buffer = buf, expr = true })
    end,
})

require "configs.video_preview"
