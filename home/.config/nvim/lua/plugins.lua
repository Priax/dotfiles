return {
    {
        "stevearc/conform.nvim",
        event = "BufWritePre", -- load before save for format on save
        opts = require "configs.conform",
    },

    -- These are some examples, uncomment them if you want to see them work!
    {
        "neovim/nvim-lspconfig",
        config = function()
            require "configs.lspconfig"
        end,
    },

    -- test new blink
    -- { import = "nvchad.blink.lazyspec" },

    -- Tronque la colonne signature du menu pour laisser la place à la doc
    {
        "hrsh7th/nvim-cmp",
        opts = function(_, opts)
            local format = opts.formatting.format
            opts.formatting.format = function(entry, item)
                item = format(entry, item)
                if item.menu and vim.fn.strchars(item.menu) > 30 then
                    item.menu = vim.fn.strcharpart(item.menu, 0, 30) .. "…"
                end
                return item
            end
            opts.window.documentation.max_width = 80

            -- .mdx : <Tab> / <S-Tab> parcourent les champs fantômes, <CR> écrit celui sélectionné
            local cmp = require "cmp"
            local mdx_props = require "configs.mdx_props"
            local confirm = cmp.mapping.confirm { behavior = cmp.ConfirmBehavior.Insert, select = true }
            opts.mapping["<Tab>"] = cmp.mapping(function(fallback)
                if mdx_props.select(1) then
                    return
                elseif cmp.visible() then
                    cmp.select_next_item()
                elseif require("luasnip").expand_or_jumpable() then
                    require("luasnip").expand_or_jump()
                else
                    fallback()
                end
            end, { "i", "s" })
            opts.mapping["<S-Tab>"] = cmp.mapping(function(fallback)
                if mdx_props.select(-1) then
                    return
                elseif cmp.visible() then
                    cmp.select_prev_item()
                elseif require("luasnip").jumpable(-1) then
                    require("luasnip").jump(-1)
                else
                    fallback()
                end
            end, { "i", "s" })
            opts.mapping["<CR>"] = cmp.mapping(function(fallback)
                if not mdx_props.accept() then
                    confirm(fallback)
                end
            end, { "i", "s" })
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = {
                "vim",
                "lua",
                "vimdoc",
                "html",
                "css",
                "javascript",
                "typescript",
                "rust",
                "c",
                "cpp",
                "haskell",
                "astro",
                "go",
                "gomod",
                "gosum",
                "gowork",
            },
            highlight = { enable = true },
            indent = { enable = true },
        },
    },

    -- 1. Markdown Preview (Aperçu dans le navigateur)
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = "cd app && npm install",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
    },

    -- 2. Image.nvim (Affichage des images dans le terminal)
    {
        "3rd/image.nvim",
        lazy = false,
        opts = {
            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = true,
                    only_render_image_at_cursor = false,
                },
            },
        },
    },

    -- 3. Gx.nvim (Ouvrir le lien ou fichier sous le curseur avec 'gx')
    {
        "chrishrb/gx.nvim",
        keys = { { "gx", "<cmd>Browse<cr>", mode = { "n", "x" } } },
        cmd = { "Browse" },
        init = function()
            vim.g.netrw_nogx = 1
        end,
        dependencies = { "nvim-lua/plenary.nvim" },
        config = true,
    },

    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            require "configs.dap"
        end,
    },
    {
        "mrcjkb/haskell-tools.nvim",
        version = "^4",
        ft = { "haskell", "lhaskell", "cabal" },
        dependencies = { "nvim-lua/plenary.nvim" },
        init = function()
            vim.g.haskell_tools = {
                hls = {
                    on_attach = function(_, bufnr, ht)
                        local opts = { buffer = bufnr }
                        -- Hoogle search mot sous le curseur
                        vim.keymap.set("n", "<leader>hs", ht.hoogle.hoogle_signature, opts)
                        -- Évaluer le code inline (commentaires -- >>>)
                        vim.keymap.set("n", "<leader>he", ht.lsp.buf_eval_all, opts)
                        -- Repl pour le fichier courant
                        vim.keymap.set("n", "<leader>hr", ht.repl.toggle, opts)
                        -- Repl pour le package
                        vim.keymap.set("n", "<leader>hR", function()
                            ht.repl.toggle(vim.api.nvim_buf_get_name(0))
                        end, opts)
                        vim.keymap.set("n", "<leader>hq", ht.repl.quit, opts)
                    end,
                },
                tools = {
                    repl = {
                        handler = "toggleterm", -- ou "builtin"
                    },
                },
            }
        end,
    },
    {
        "leoluz/nvim-dap-go",
        ft = "go",
        dependencies = "mfussenegger/nvim-dap",
        config = function(_, opts)
            require("dap-go").setup(opts)
        end,
    },
    {
        "sindrets/diffview.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        cmd = {
            "DiffviewOpen",
            "DiffviewClose",
            "DiffviewToggleFiles",
            "DiffviewFocusFiles",
            "DiffviewFileHistory",
        },
    },
}
