local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- mes plugins se chargent au démarrage, sauf s'ils précisent ft, cmd, keys…
    lazy = false,
    -- dernier commit plutôt que dernière release (souvent vieille), les versions sont figées
    -- par lazy-lock.json
    version = false,
  },
  install = { colorscheme = { "catppuccin-nvim", "habamax" } },
  -- Seul image.nvim déclare un rock (magick), dont il n'a pas besoin: il passe par la commande
  -- magick. Sans ça, hererocks s'installe sur Linux et pas sur Mac, et lazy-lock.json diffère.
  rocks = { enabled = false },
  -- Pas de vérification en tâche de fond: les mises à jour passent par « dot upgrade »
  checker = { enabled = false },
  performance = {
    rtp = {
      -- plugins fournis avec nvim, inutiles ici
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
