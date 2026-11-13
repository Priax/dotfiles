-- Pas d'extra lang.haskell: il ajoute LuaSnip et des paquets Mason (hlint, haskell-debug-adapter),
-- alors qu'ici hls, fourmolu et cabal-fmt viennent de ghcup et de dot install.
return {
    {
        "mrcjkb/haskell-tools.nvim",
        version = "^11",
        lazy = false,
        init = function()
            vim.g.haskell_tools = {
                hls = {
                    settings = {
                        haskell = {
                            cabalFormattingProvider = "cabalfmt",
                            formattingProvider = "fourmolu",
                            checkProject = true,
                        },
                    },
                    on_attach = function(_, bufnr, ht)
                        local function map(lhs, rhs, desc)
                            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
                        end
                        map("<leader>Hs", ht.hoogle.hoogle_signature, "Hoogle: signature sous le curseur")
                        map("<leader>He", ht.lsp.buf_eval_all, "Évaluer le code inline (-- >>>)")
                        map("<leader>Hr", ht.repl.toggle, "REPL du fichier courant")
                        map("<leader>HR", function()
                            ht.repl.toggle(vim.api.nvim_buf_get_name(0))
                        end, "REPL du package")
                        map("<leader>Hq", ht.repl.quit, "Quitter le REPL")
                    end,
                },
                tools = {
                    repl = {
                        handler = "builtin",
                    },
                },
            }
        end,
    },
    {
        "folke/which-key.nvim",
        opts = { spec = { { "<leader>H", group = "haskell" } } },
    },
}
