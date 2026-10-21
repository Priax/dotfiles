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
