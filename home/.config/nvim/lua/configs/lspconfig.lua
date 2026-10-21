require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "ts_ls", "rust_analyzer", "clangd", "eslint", "gopls", "mdx_analyzer", "astro" }

local on_attach = require("nvchad.configs.lspconfig").on_attach
local capabilities = require("nvchad.configs.lspconfig").capabilities

-- HTML
vim.lsp.config.html = {
    on_attach = on_attach,
    capabilities = capabilities,
}

-- CSS
vim.lsp.config.cssls = {
    on_attach = on_attach,
    capabilities = capabilities,
}

-- TypeScript / JavaScript
vim.lsp.config.ts_ls = {
    on_attach = on_attach,
    capabilities = capabilities,
}

-- ESLint
local eslint_default_before_init = (vim.lsp.config.eslint or {}).before_init
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
        on_attach(client, bufnr)
        local group = vim.api.nvim_create_augroup("EslintAutoFix", { clear = false })
        vim.api.nvim_clear_autocmds { buffer = bufnr, group = group }
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            group = group,
            callback = function()
                vim.lsp.buf_request_sync(bufnr, "workspace/executeCommand", {
                    command = "eslint.applyAllFixes",
                    arguments = {
                        {
                            uri = vim.uri_from_bufnr(bufnr),
                            version = 0,
                        },
                    },
                }, 1000)
            end,
        })
    end,
    capabilities = capabilities,
    -- useFlatConfig only when the project has an eslint.config.*, otherwise
    -- .eslintrc projects fail with "Could not find config file"
    before_init = function(params, config)
        if eslint_default_before_init then
            eslint_default_before_init(params, config)
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
--     on_attach = on_attach,
--     capabilities = capabilities,
--     cmd = { "biome", "lsp-proxy" },
--     filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc" },
--     root_markers = { "biome.json", "biome.jsonc" },
--     single_file_support = false,
-- }

-- C / C++
vim.lsp.config.clangd = {
    cmd = { "clangd", "--background-index" },
    on_attach = on_attach,
    capabilities = capabilities,
    root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
}

-- Rust
vim.lsp.config.rust_analyzer = {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = {
        ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = true,
        },
    },
}

-- Golang
vim.lsp.config.gopls = {
    on_attach = on_attach,
    capabilities = capabilities,
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
-- typescript.enabled : sans ça, mdx-analyzer ne fait ni survol (K) ni complétion des composants
vim.lsp.config.mdx_analyzer = {
    on_attach = on_attach,
    capabilities = capabilities,
    init_options = { typescript = { enabled = true } },
}

-- Astro, seulement pour le frontmatter des .mdx (contentIntellisense : schémas de
-- .astro/collections/, générés si experimental.contentIntellisense est activé)
vim.lsp.config.astro = {
    on_attach = on_attach,
    capabilities = capabilities,
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
