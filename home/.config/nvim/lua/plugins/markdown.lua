-- Pas l'extra lang.markdown de LazyVim: il renomme le filetype des .mdx en « markdown.mdx »
-- (ici « mdx », attendu par mdx_analyzer et configs/mdx_*.lua) et ajoute markdownlint.
-- marksman est déclaré dans plugins/lsp.lua.
return {
    -- Aperçu Markdown dans le navigateur
    {
        "brianhuster/live-preview.nvim",
        cmd = "LivePreview",
    },

    -- Rendu Markdown dans le buffer
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "mdx" },
        opts = {
            file_types = { "markdown", "mdx" },
            completions = { lsp = { enabled = true } },
        },
    },

    -- Image.nvim (Affichage des images dans le terminal)
    {
        "3rd/image.nvim",
        lazy = false,
        opts = {
            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = true,
                    only_render_image_at_cursor = false,
                    filetypes = { "markdown", "vimwiki", "mdx" },
                },
            },
        },
    },
}
