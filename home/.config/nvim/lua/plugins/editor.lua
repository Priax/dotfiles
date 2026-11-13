return {
    -- flash ne prend pas ; (mode commande, config/keymaps.lua): retaper f/t répète le saut
    {
        "folke/flash.nvim",
        opts = {
            modes = {
                char = { keys = { "f", "F", "t", "T", "," } },
            },
        },
    },

    -- gx ouvre le lien ou le fichier sous le curseur
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
