require("nvchad.configs.lspconfig").defaults()

local servers =
    { "html", "cssls", "ts_ls", "rust_analyzer", "clangd", "eslint", "gopls", "mdx_analyzer", "marksman", "astro" }

-- defaults() règle déjà capabilities (vim.lsp.config "*") et on_attach (autocmd LspAttach)
-- pour tous les serveurs, et nvim-lspconfig fournit cmd/filetypes/root_markers (lsp/<nom>.lua):
-- un serveur sans réglage particulier n'a besoin que de figurer dans `servers`

-- ESLint
local eslint_default = vim.lsp.config.eslint or {}
local eslint_flat_config_files = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
}
vim.lsp.config.eslint = {
    on_attach = function(client, bufnr)
        -- celui de nvim-lspconfig crée :LspEslintFixAll
        if eslint_default.on_attach then
            eslint_default.on_attach(client, bufnr)
        end
        local group = vim.api.nvim_create_augroup("EslintAutoFix", { clear = false })
        vim.api.nvim_clear_autocmds { buffer = bufnr, group = group }
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            group = group,
            callback = function()
                -- client:request_sync et pas vim.lsp.buf_request_sync: la requête n'allait pas qu'à eslint
                -- mais à tous les serveurs du buffer (ts_ls…), et la sauvegarde attendait le plus lent
                client:request_sync("workspace/executeCommand", {
                    command = "eslint.applyAllFixes",
                    arguments = {
                        {
                            uri = vim.uri_from_bufnr(bufnr),
                            version = vim.lsp.util.buf_versions[bufnr],
                        },
                    },
                }, 1000, bufnr)
            end,
        })
    end,
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
}

-- vim.lsp.config.biome = {
--     cmd = { "biome", "lsp-proxy" },
--     filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc" },
--     root_markers = { "biome.json", "biome.jsonc" },
--     single_file_support = false,
-- }

-- C / C++
vim.lsp.config.clangd = {
    cmd = { "clangd", "--background-index" },
    root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
}

-- Rust
vim.lsp.config.rust_analyzer = {
    settings = {
        ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = true,
        },
    },
}

-- Golang
vim.lsp.config.gopls = {
    settings = {
        gopls = {
            completeUnimported = true,
            usePlaceholders = true,
            analyses = {
                unusedparams = true,
            },
            staticcheck = true,
        },
    },
}

-- MDX
-- typescript.enabled: sans ça, mdx-analyzer ne fait ni survol (K) ni complétion des composants
local mdx_default = vim.lsp.config.mdx_analyzer or {}
vim.lsp.config.mdx_analyzer = {
    init_options = { typescript = { enabled = true } },
    before_init = function(params, config)
        -- celui de nvim-lspconfig prend le TypeScript du projet (node_modules)
        if mdx_default.before_init then
            mdx_default.before_init(params, config)
        end
        -- hors projet, chemin vide et le serveur plante (« Can't find typescript.js »):
        -- repli sur le TypeScript embarqué par typescript-language-server (Mason)
        local ts = config.init_options.typescript
        if not ts.tsdk or ts.tsdk == "" then
            ts.tsdk = vim.fn.stdpath "data" .. "/mason/packages/typescript-language-server/node_modules/typescript/lib"
        end
    end,
}

-- Astro, seulement pour le frontmatter des .mdx (contentIntellisense: schémas de
-- .astro/collections/, générés si experimental.contentIntellisense est activé)
vim.lsp.config.astro = {
    filetypes = { "mdx" },
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, { "astro.config.mjs", "astro.config.ts", "astro.config.js" })
        if root then
            on_dir(root)
        end
    end,
    init_options = { typescript = {}, contentIntellisense = true },
}

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
