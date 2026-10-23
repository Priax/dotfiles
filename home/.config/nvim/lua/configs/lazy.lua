return {
    defaults = { lazy = true },
    install = { colorscheme = { "nvchad" } },

    checker = {
        enabled = true,
        notify = false,
    },

    change_detection = {
        notify = false,
    },

    -- Seul image.nvim déclare un rock (magick), mais il utilise le CLI ImageMagick (magick_cli).
    -- Sans ça, hererocks s'installe sur Linux et pas sur Mac, et lazy-lock.json diffère.
    rocks = { enabled = false },

    ui = {
        icons = {
            ft = "",
            lazy = "󰂠 ",
            loaded = "",
            not_loaded = "",
        },
    },

    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "netrwPlugin",
                "matchit",
                "tarPlugin",
                "zipPlugin",
                "tutor",
                "rplugin",
            },
        },
    },
}
