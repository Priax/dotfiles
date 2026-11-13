-- Chargé sur l'événement VeryLazy, après les keymaps de LazyVim:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- ; passe en mode commande. Celui de flash.nvim (répéter f/t) est sur <leader>; (plugins/editor.lua)
map("n", ";", ":", { desc = "Mode commande" })

-- rangé avec les diagnostics (<leader>x), <leader>q étant le groupe « quit » de LazyVim
map("n", "<leader>xd", function()
    vim.diagnostic.setqflist()
end, { desc = "Diagnostics dans la quickfix" })

map("n", "<leader>o", function()
    -- dans l'explorateur, on prend le fichier sélectionné. Dans un picker ou un terminal, le
    -- nom du buffer n'est pas un fichier.
    local file = vim.fn.expand "%:p"
    if vim.bo.filetype == "snacks_picker_list" then
        local explorer = Snacks.picker.get({ source = "explorer" })[1]
        local item = explorer and explorer:current()
        file = item and item.file or ""
    elseif vim.bo.buftype ~= "" then
        file = ""
    end
    if file ~= "" and vim.uv.fs_stat(file) then
        vim.ui.open(file)
        vim.notify("Fichier ouvert: " .. file)
    else
        vim.notify("Aucun fichier à ouvrir", vim.log.levels.WARN)
    end
end, { desc = "Ouvrir le fichier avec l'application système" })

-- Terminaux. Le <C-/> de LazyVim ne marche pas en AZERTY, où / se tape avec Maj. On reprend
-- les touches de NvChad, qui cachent aussi le terminal quand on est dedans (plugins/ui.lua).
-- Le terminal 1 est le même que celui de <C-/> et <leader>ft.
for key, term in pairs {
    ["<A-h>"] = { count = 1, position = "bottom", desc = "Terminal en bas" },
    ["<A-v>"] = { count = 2, position = "right", desc = "Terminal à droite" },
    ["<A-i>"] = { count = 3, position = "float", desc = "Terminal flottant" },
} do
    map("n", key, function()
        local win = { position = term.position }
        if term.position == "right" then
            win.width = 0.4
        elseif term.position == "float" then
            win.border = "rounded"
        end
        Snacks.terminal.focus(nil, { cwd = LazyVim.root(), count = term.count, win = win })
    end, { desc = term.desc })
end

-- AZERTY: [ et ] demandent AltGr. ç et à, côte à côte et libres en mode normal, les remplacent:
-- çd / àd = [d / ]d, çh / àh, çb / àb… Avec remap, tous les [x / ]x suivent (LazyVim, plugins,
-- natifs), which-key compris.
map({ "n", "x", "o" }, "ç", "[", { remap = true, desc = "Préfixe [ (précédent)" })
map({ "n", "x", "o" }, "à", "]", { remap = true, desc = "Préfixe ] (suivant)" })
