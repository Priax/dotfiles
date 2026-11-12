-- Les serveurs déclarés ici sont installés par Mason (mason-lspconfig) et activés par LazyVim.
-- Viennent des extras: vtsls (lang.typescript), gopls (lang.go), clangd (lang.clangd),
-- rust-analyzer (lang.rust, via rustaceanvim et rustup), la base d'eslint (linting.eslint,
-- qui corrige aussi à la sauvegarde). hls est lancé par haskell-tools (plugins/haskell.lua).

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
            -- configs de nvim-lspconfig (lsp/<nom>.lua), lues avant que LazyVim n'y fusionne celles-ci:
            -- un before_init déclaré ici remplace le leur, il doit donc l'appeler
            local eslint_default = vim.lsp.config.eslint or {}
            local mdx_default = vim.lsp.config.mdx_analyzer or {}

            -- Types et noms de paramètres en gris dans le code: éteints au démarrage,
            -- <leader>uh les affiche / les cache
            opts.inlay_hints.enabled = false

            opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
                html = {},
                cssls = {},
                marksman = {},

                eslint = {
                    -- useFlatConfig only when the project has an eslint.config.*, otherwise
                    -- .eslintrc projects fail with "Could not find config file"
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

                -- goimports seul au formatage, pas gofumpt (plugins/formatting.lua)
                gopls = { settings = { gopls = { gofumpt = false } } },

                -- typescript.enabled: sans ça, mdx-analyzer ne fait ni survol (K) ni complétion des composants
                mdx_analyzer = {
                    init_options = { typescript = { enabled = true } },
                    before_init = function(params, config)
                        -- celui de nvim-lspconfig prend le TypeScript du projet (node_modules)
                        if mdx_default.before_init then
                            mdx_default.before_init(params, config)
                        end
                        -- hors projet, chemin vide et le serveur plante (« Can't find typescript.js »):
                        -- repli sur le TypeScript embarqué par vtsls (Mason)
                        local ts = config.init_options.typescript
                        if not ts.tsdk or ts.tsdk == "" then
                            ts.tsdk = vim.fn.stdpath "data"
                                .. "/mason/packages/vtsls/node_modules/@vtsls/language-server/node_modules/typescript/lib"
                        end
                    end,
                },

                -- Astro, seulement pour le frontmatter des .mdx (contentIntellisense: schémas de
                -- .astro/collections/, générés si experimental.contentIntellisense est activé)
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

    -- Ce qu'aucun extra ne déclare: les formatters de plugins/formatting.lua
    -- (stylua, goimports, codelldb et delve viennent de LazyVim et de ses extras)
    {
        "mason-org/mason.nvim",
        opts = function(_, opts)
            vim.list_extend(opts.ensure_installed, { "biome", "prettier", "clang-format" })
            -- codelldb est déclaré par lang.rust et lang.clangd: sans dédoublonnage, LazyVim lance
            -- deux fois son installation et Mason plante (« Package is already installing »)
            opts.ensure_installed = LazyVim.dedup(opts.ensure_installed)
        end,
    },
}
