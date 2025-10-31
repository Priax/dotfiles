vim.api.nvim_create_user_command("AddHeader", function()
    local full_path = vim.fn.expand("%:~")
    local header = {
        "/*",
        "** Priax PROJECT",
        "** " .. full_path,
        "** File description:",
        "** " .. vim.fn.expand("%:t:r"),
        "**",
        ""
    }

    -- Récupérer tout le contenu actuel du buffer
    local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Créer un nouveau tableau : header + contenu original
    local new_lines = {}
    vim.list_extend(new_lines, header)
    vim.list_extend(new_lines, current_lines)

    -- Remplacer tout le buffer par new_lines
    vim.api.nvim_buf_set_lines(0, 0, -1, false, new_lines)
end, {})

