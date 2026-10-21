require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd

autocmd("FileType", {
    pattern = "*",
    callback = function(args)
        -- j: retire le commentaire si la ligne devient vide après un join
        -- o: retire l'auto-commentaire après 'o' ou 'O'
        -- r: retire l'auto-commentaire après <Enter> en mode insertion
        vim.opt_local.formatoptions:remove { "r", "o", "j" }

        if vim.bo.buftype == "" and pcall(vim.treesitter.start, args.buf) then
            vim.opt_local.foldmethod = "expr"
            vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

-- MDX : le parseur MDX ne tolère pas un JSX incomplet, donc mdx-analyzer ne complète
-- un composant que si sa balise est fermée. On ferme `<Nom` en `<Nom />` dès la première lettre,
-- grisé tant que ce n'est qu'un bouche-trou (`>` le retire, `/` le garde).
local autoclose_ns = vim.api.nvim_create_namespace "mdx_autoclose"

autocmd("FileType", {
    pattern = "mdx",
    callback = function(args)
        local buf = args.buf
        require("configs.mdx_props").attach(buf)

        local function keep_close()
            vim.api.nvim_buf_clear_namespace(buf, autoclose_ns, 0, -1)
        end

        local function dim(row, col, len)
            keep_close()
            vim.api.nvim_buf_set_extmark(buf, autoclose_ns, row, col, { end_col = col + len, hl_group = "Comment" })
        end

        -- Dans `<Nom … />` encore grisé, un mot qui n'est pas une prop du composant est le début
        -- du contenu : `<Censor salut ` devient `<Censor>salut `
        local function to_children(row, col, line)
            local before, after = line:sub(1, col), line:sub(col + 1)
            if not after:match "^/>" or #vim.api.nvim_buf_get_extmarks(buf, autoclose_ns, { row, 0 }, { row, -1 }, {}) == 0 then
                return
            end
            local start, name
            for s, n in before:gmatch "()<(%u[%w.]*)" do
                start, name = s, n
            end
            local props = name and require("configs.mdx_props").prop_names(buf, name)
            if not props then
                return
            end
            local attrs = before:sub(start + #name + 1)
            local hide = function(m)
                return ("\1"):rep(#m)
            end
            local masked = attrs:gsub('"[^"]*"', hide):gsub("{[^{}]*}", hide)
            if masked:find '"' or masked:find "{" then
                return
            end
            for s, word, e in masked:gmatch "()([^%s]+)()" do
                local done = e <= #masked or word:find "[^%w_-]"
                if not word:find "=" and done and not props[word] then
                    local head = before:sub(1, start + #name) .. attrs:sub(1, s - 1):gsub("%s+$", "")
                    local text = head .. ">" .. attrs:sub(s)
                    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { text .. after:sub(3) })
                    vim.api.nvim_win_set_cursor(0, { row + 1, #text })
                    return keep_close()
                end
            end
        end

        autocmd("TextChangedI", {
            buffer = buf,
            callback = function()
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                local line = vim.api.nvim_get_current_line()
                local before = line:sub(1, col)
                if before:match "<%u$" and not before:match "%w<%u$" and line:sub(col + 1) == "" then
                    vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, { " />" })
                    dim(row - 1, col, 3)
                else
                    to_children(row - 1, col, line)
                end
            end,
        })
        autocmd("InsertLeave", { buffer = buf, callback = keep_close })

        local function after_cursor()
            local col = vim.api.nvim_win_get_cursor(0)[2]
            return vim.api.nvim_get_current_line():sub(col + 1)
        end

        -- `>` : composant avec enfants, on retire le ` />` ajouté
        vim.keymap.set("i", ">", function()
            local close = after_cursor():match "^ ?/>"
            if close then
                keep_close()
            end
            return close and ("<Del>"):rep(#close) .. ">" or ">"
        end, { buffer = buf, expr = true })

        -- `/` : on saute par-dessus le ` />` existant
        vim.keymap.set("i", "/", function()
            local close = after_cursor():match "^ ?/>"
            if close then
                keep_close()
            end
            return close and ("<Right>"):rep(#close) or "/"
        end, { buffer = buf, expr = true })

        -- espace juste après le nom : on réutilise celui du ` />`
        vim.keymap.set("i", "<Space>", function()
            if not after_cursor():match "^ />" then
                return " "
            end
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            dim(row - 1, col + 1, 2)
            return "<Right>"
        end, { buffer = buf, expr = true })
    end,
})

require "configs.video_preview"
