-- Les serveurs déclarés ici sont installés par Mason et activés par LazyVim. D'autres viennent
-- des extras: vtsls, gopls, clangd, rust-analyzer (par rustaceanvim, installé avec rustup) et
-- eslint (qui corrige aussi à la sauvegarde). hls est lancé par haskell-tools (plugins/haskell.lua).

local eslint_flat_config_files = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
}

return {
    {
        "neovim/nvim-lspconfig",
        opts = function(_, opts)
            -- Les configs de nvim-lspconfig (lsp/<nom>.lua), lues avant que LazyVim y ajoute
            -- celles d'ici. Un before_init déclaré ici remplace le leur, il doit donc l'appeler.
            local eslint_default = vim.lsp.config.eslint or {}
            local mdx_default = vim.lsp.config.mdx_analyzer or {}

            -- types et noms de paramètres en gris dans le code: cachés, <leader>uh pour les voir
            opts.inlay_hints.enabled = false

            opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
                html = {},
                cssls = {},
                marksman = {},

                -- biome est installé pour le formatage (plugins/formatting.lua), et
                -- mason-lspconfig démarre tout LSP installé: on ne veut pas de son serveur
                biome = { enabled = false },

                eslint = {
                    -- useFlatConfig seulement si le projet a un eslint.config.*, sinon les projets
                    -- en .eslintrc échouent (« Could not find config file »)
                    before_init = function(params, config)
                        if eslint_default.before_init then
                            eslint_default.before_init(params, config)
                        end
                        local flat_config = vim.fs.find(eslint_flat_config_files, {
                            path = config.root_dir,
                            type = "file",
                            limit = 1,
                            upward = true,
                        })[1]
                        local settings = config.settings or {}
                        local experimental = settings.experimental or {}
                        ---@cast experimental table<string, any>
                        experimental.useFlatConfig = flat_config ~= nil
                        settings.experimental = experimental
                        config.settings = settings
                    end,
                },

                -- goimports seul, pas gofumpt (plugins/formatting.lua)
                gopls = { settings = { gopls = { gofumpt = false } } },

                -- sans typescript.enabled, pas de survol (K) ni de complétion des composants
                mdx_analyzer = {
                    init_options = { typescript = { enabled = true } },
                    before_init = function(params, config)
                        -- celui de nvim-lspconfig prend le TypeScript du projet (node_modules)
                        if mdx_default.before_init then
                            mdx_default.before_init(params, config)
                        end
                        -- hors d'un projet, le chemin est vide et le serveur plante (« Can't find
                        -- typescript.js »): on prend le TypeScript fourni avec vtsls
                        local ts = config.init_options.typescript
                        if not ts.tsdk or ts.tsdk == "" then
                            ts.tsdk = vim.fn.stdpath "data"
                                .. "/mason/packages/vtsls/node_modules/@vtsls/language-server/node_modules/typescript/lib"
                        end
                    end,
                },

                -- Astro, seulement pour le frontmatter des .mdx. contentIntellisense lit les
                -- schémas de .astro/collections/, générés quand le projet active
                -- experimental.contentIntellisense.
                astro = {
                    filetypes = { "mdx" },
                    root_dir = function(bufnr, on_dir)
                        local root = vim.fs.root(bufnr, { "astro.config.mjs", "astro.config.ts", "astro.config.js" })
                        if root then
                            on_dir(root)
                        end
                    end,
                    init_options = { typescript = {}, contentIntellisense = true },
                },
            })
        end,
    },

    -- Les formatters de plugins/formatting.lua qu'aucun extra n'installe
    {
        "mason-org/mason.nvim",
        opts = function(_, opts)
            vim.list_extend(opts.ensure_installed, { "biome", "prettier", "clang-format" })
            -- codelldb est demandé par lang.rust et par lang.clangd. En double, LazyVim lance deux
            -- installations et Mason plante (« Package is already installing »).
            opts.ensure_installed = LazyVim.dedup(opts.ensure_installed)
        end,
    },
}
