-- Pas d'extra lang.markdown: il passe le filetype des .mdx en « markdown.mdx », alors que
-- mdx_analyzer et configs/mdx_*.lua attendent « mdx ». Il ajoute aussi markdownlint.
-- marksman est dans plugins/lsp.lua.
return {
    -- aperçu dans le navigateur
    {
        "brianhuster/live-preview.nvim",
        cmd = "LivePreview",
    },

    -- rendu dans le buffer
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "mdx" },
        opts = {
            file_types = { "markdown", "mdx" },
            completions = { lsp = { enabled = true } },
        },
    },

    -- images dans le terminal. Chargé avec un fichier markdown, ou par le require("image") de
    -- l'aperçu des vidéos (configs/video_preview.lua)
    {
        "3rd/image.nvim",
        ft = { "markdown", "vimwiki", "mdx" },
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
