-- Thèmes en plus de catppuccin (plugins/ui.lua) et tokyonight (fourni par LazyVim): ceux de
-- NvChad qui existent en plugin. Chargés seulement quand on les choisit (<leader>uC les liste
-- quand même). Variantes claires: :set bg=light pour gruvbox, onedark, vscode, everforest…
-- `name`: plusieurs dépôts s'appellent « vim » ou « nvim »

local themes = {
    { "rebelot/kanagawa.nvim" }, -- kanagawa, -wave, -dragon, -lotus
    { "EdenEast/nightfox.nvim" }, -- nightfox, carbonfox, duskfox, nordfox, terafox, dayfox, dawnfox
    { "rose-pine/neovim", name = "rose-pine" }, -- rose-pine, -moon, -dawn
    { "nyoom-engineering/oxocarbon.nvim" },
    { "Shatur/neovim-ayu" }, -- ayu-dark, ayu-mirage, ayu-light
    { "sainnhe/everforest" },
    { "AlexvZyl/nordic.nvim" },
    { "FrenzyExists/aquarium-vim" },
    { "Ferouk/bearded-nvim" },
    { "xiantang/darcula-dark.nvim" },
    { "decaycs/decay.nvim", name = "decay" },
    { "Mofiqul/dracula.nvim" }, -- chadracula de NvChad
    { "eldritch-theme/eldritch.nvim" },
    { "embark-theme/vim", name = "embark" },
    { "Everblush/nvim", name = "everblush" },
    { "fenetikm/falcon" },
    { "kepano/flexoki-neovim", name = "flexoki" },
    { "maxmx03/fluoromachine.nvim" },
    { "projekt0n/github-nvim-theme" }, -- github_dark, github_light…
    { "ellisonleao/gruvbox.nvim" },
    { "akinsho/horizon.nvim" },
    { "jabuti-theme/jabuti-nvim" },
    { "wtfox/jellybeans.nvim" },
    { "marko-cerovac/material.nvim" }, -- material-darker, -deep-ocean, -palenight, -lighter…
    { "savq/melange-nvim" },
    { "kdheepak/monochrome.nvim" },
    { "mountain-theme/vim", name = "mountain" },
    { "diegoulloao/neofusion.nvim" },
    { "oxfist/night-owl.nvim" },
    { "shaunsingh/nord.nvim" },
    { "mhartington/oceanic-next" },
    { "navarasu/onedark.nvim" },
    { "rmehri01/onenord.nvim" },
    { "Allianaab2m/penumbra.nvim" },
    { "olivercederborg/poimandres.nvim" },
    { "junegunn/seoul256.vim" }, -- seoul256, seoul256-light
    { "maxmx03/solarized.nvim" },
    { "craftzdog/solarized-osaka.nvim" },
    { "tiagovla/tokyodark.nvim" },
    { "sam4llis/nvim-tundra" },
    { "datsfilipe/vesper.nvim" },
    { "Mofiqul/vscode.nvim" },
    { "phha/zenburn.nvim" },
}

for _, theme in ipairs(themes) do
    theme.lazy = true
end

return themes
