require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "ts_ls", "rust_analyzer" }

-- local lspconfig = require "lspconfig" -- soon to be deprecated, to change to "vim.lsp.config"
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
vim.lsp.config.tsserver = {
  on_attach = on_attach,
  capabilities = capabilities,
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

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
