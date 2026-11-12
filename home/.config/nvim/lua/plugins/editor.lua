return {
    -- `;` sert à entrer en mode commande (config/keymaps.lua): la répétition de f/t passe sur <leader>;
    {
        "folke/flash.nvim",
        opts = {
            modes = {
                char = { keys = { "f", "F", "t", "T", [";"] = "<leader>;", "," } },
            },
        },
    },

    -- Gx.nvim (Ouvrir le lien ou fichier sous le curseur avec 'gx')
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
        "esmuellert/codediff.nvim",
        cmd = "CodeDiff",
    },
}
