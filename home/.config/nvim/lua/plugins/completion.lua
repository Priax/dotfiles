return {
    {
        "saghen/blink.cmp",
        opts = function(_, opts)
            -- colonne de la signature plus étroite, pour laisser de la place à la doc
            opts.completion = vim.tbl_deep_extend("force", opts.completion or {}, {
                menu = { draw = { components = { label_description = { width = { max = 30 } } } } },
                documentation = { window = { max_width = 80 } },
            })

            -- Dans un .mdx, <Tab> / <S-Tab> parcourent les props fantômes et <CR> écrit celle
            -- sélectionnée. Ailleurs, ce sont les touches habituelles de LazyVim.
            local mdx_props = require "configs.mdx_props"
            -- blink appelle ces fonctions dans un mapping <expr>, où on ne peut pas modifier le
            -- buffer: on teste tout de suite et on reporte l'action (vim.schedule)
            local function ghost(selected, action)
                return function()
                    if not mdx_props.has_ghost(selected) then
                        return false
                    end
                    vim.schedule(action)
                    return true
                end
            end
            opts.keymap = vim.tbl_extend("force", opts.keymap or {}, {
                ["<Tab>"] = {
                    ghost(false, function()
                        mdx_props.select(1)
                    end),
                    LazyVim.cmp.map { "snippet_forward", "ai_nes", "ai_accept" },
                    "fallback",
                },
                ["<S-Tab>"] = {
                    ghost(false, function()
                        mdx_props.select(-1)
                    end),
                    "snippet_backward",
                    "fallback",
                },
                ["<CR>"] = { ghost(true, mdx_props.accept), "accept", "fallback" },
            })
        end,
    },
}
