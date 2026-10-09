-- Aperçu des vidéos dans nvim : infos (ffprobe) + planche de miniatures (ffmpeg),
-- affichée via image.nvim, au lieu d'ouvrir le binaire.
-- Dans le buffer : `o` ouvre la vidéo avec le lecteur par défaut.

local exts = { "mp4", "mkv", "webm", "mov", "avi", "m4v", "flv", "wmv" }
local cache_dir = vim.fn.stdpath "cache" .. "/video-thumbs"
vim.fn.mkdir(cache_dir, "p")

local group = vim.api.nvim_create_augroup("VideoPreview", { clear = true })
local images = {} -- buf -> image

local function fmt_duration(s)
    s = math.floor(tonumber(s) or 0)
    return string.format("%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
end

local function fmt_size(b)
    b = tonumber(b) or 0
    local units = { "o", "Ko", "Mo", "Go" }
    local i = 1
    while b >= 1024 and i < #units do
        b, i = b / 1024, i + 1
    end
    return string.format("%.1f %s", b, units[i])
end

local function probe(file)
    local res = vim.system({
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "format=duration,size:stream=width,height,codec_name,r_frame_rate",
        "-of", "json", file,
    }, { text = true }):wait()
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    if not ok or not data then
        return nil
    end
    local st = (data.streams or {})[1] or {}
    local fmt = data.format or {}
    local num, den = (st.r_frame_rate or "0/1"):match "(%d+)/(%d+)"
    local fps = (tonumber(den) or 0) > 0 and tonumber(num) / tonumber(den) or 0
    return {
        duration = tonumber(fmt.duration) or 0,
        lines = {
            "  " .. vim.fn.fnamemodify(file, ":t"),
            "",
            "  Durée      " .. fmt_duration(fmt.duration),
            "  Résolution " .. (st.width or "?") .. "x" .. (st.height or "?"),
            string.format("  Codec      %s @ %.2f fps", st.codec_name or "?", fps),
            "  Taille     " .. fmt_size(fmt.size),
            "",
            "  [o] ouvrir dans le lecteur",
            "",
        },
    }
end

local function render(buf)
    local img = images[buf]
    local win = vim.fn.bufwinid(buf)
    if img and win ~= -1 then
        img.window = win
        img:render()
    end
end

local function show_thumb(buf, thumb, y)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local win = vim.fn.bufwinid(buf)
    if win == -1 then
        win = vim.api.nvim_get_current_win()
    end
    local img = require("image").from_file(thumb, {
        window = win,
        buffer = buf,
        x = 2,
        y = y,
    })
    if img then
        images[buf] = img
        img:render()
    end
end

vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = vim.tbl_map(function(e)
        return "*." .. e
    end, exts),
    callback = function(args)
        local buf = args.buf
        local file = vim.fn.fnamemodify(args.file, ":p")
        local info = probe(file) or { duration = 0, lines = { "  (ffprobe a échoué)", "" } }

        vim.bo[buf].buftype = "nowrite"
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, info.lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].filetype = "video_preview"
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.cursorline = false

        vim.keymap.set("n", "o", function()
            vim.ui.open(file)
        end, { buffer = buf, desc = "Ouvrir la vidéo" })

        -- miniature en cache, invalidée si le fichier change
        local mtime = (vim.uv.fs_stat(file) or {}).mtime or { sec = 0 }
        local thumb = string.format("%s/%s.png", cache_dir, vim.fn.sha256(file .. mtime.sec))
        -- y est indexé à 0 : on ancre l'image sur la dernière ligne (vide)
        local y = #info.lines - 1

        if vim.uv.fs_stat(thumb) then
            show_thumb(buf, thumb, y)
            return
        end

        -- planche 3x3 répartie sur toute la durée de la vidéo
        local fps = info.duration > 0 and (9 / info.duration) or 1
        vim.system({
            "ffmpeg", "-v", "error", "-y", "-i", file,
            "-vf", string.format("fps=%f,scale=320:-1,tile=3x3:padding=4", fps),
            "-frames:v", "1", "-update", "1", thumb,
        }, {}, vim.schedule_wrap(function(res)
            if res.code == 0 then
                show_thumb(buf, thumb, y)
            else
                vim.notify("Miniature vidéo impossible : " .. (res.stderr or ""), vim.log.levels.WARN)
            end
        end))
    end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
        if images[args.buf] then
            render(args.buf)
        end
    end,
})

vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWipeout" }, {
    group = group,
    callback = function(args)
        local img = images[args.buf]
        if img then
            img:clear()
            if args.event == "BufWipeout" then
                images[args.buf] = nil
            end
        end
    end,
})
