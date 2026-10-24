-- Aperçu des vidéos dans nvim: infos (ffprobe) + planche de miniatures (ffmpeg),
-- affichée via image.nvim, au lieu d'ouvrir le binaire.
-- Dans le buffer: `o` ouvre la vidéo avec le lecteur par défaut.

local exts = { "mp4", "mkv", "webm", "mov", "avi", "m4v", "flv", "wmv" }
local cache_dir = vim.fn.stdpath "cache" .. "/video-thumbs"

local group = vim.api.nvim_create_augroup("VideoPreview", { clear = true })
local images = {} -- buf -> image
local pending = {} -- buf -> { thumb, y }: miniature prête alors que le buffer n'était pas affiché

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

-- vim.system lève une erreur si l'exécutable n'existe pas (ffmpeg absent sur une autre machine)
local function system(cmd, opts, on_exit)
    if vim.fn.executable(cmd[1]) == 0 then
        return nil
    end
    return vim.system(cmd, opts, on_exit)
end

local function probe(file)
    local job = system({
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "format=duration,size:stream=width,height,codec_name,r_frame_rate",
        "-of",
        "json",
        file,
    }, { text = true })
    if not job then
        return nil
    end
    -- bloquant: on attend au plus 3 s (fichier sur un montage réseau lent)
    local res = job:wait(3000)
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

-- Planche 3x3: une image au milieu de chaque neuvième de la vidéo. Un `-ss` avant chaque `-i`
-- saute directement à l'instant voulu, au lieu de décoder toute la vidéo avec le filtre fps
-- (0,6 s au lieu de 13 s pour 10 min en 720p, et indépendant de la durée).
local function thumb_cmd(file, duration, thumb)
    local cmd = { "ffmpeg", "-v", "error", "-y" }
    local filters, inputs = {}, {}
    for i = 0, 8 do
        vim.list_extend(cmd, { "-ss", string.format("%.3f", duration * (i + 0.5) / 9), "-i", file })
        table.insert(filters, string.format("[%d:v]trim=end_frame=1,setpts=PTS-STARTPTS[v%d]", i, i))
        table.insert(inputs, string.format("[v%d]", i))
    end
    local graph = table.concat(filters, ";")
        .. ";"
        .. table.concat(inputs)
        .. "concat=n=9:v=1:a=0,scale=320:-1,tile=3x3:padding=4"
    vim.list_extend(cmd, { "-filter_complex", graph, "-frames:v", "1", "-update", "1", thumb })
    return cmd
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
        -- buffer quitté pendant la génération: on affichera au prochain BufWinEnter
        pending[buf] = { thumb = thumb, y = y }
        return
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
        local info = probe(file) or { duration = 0, lines = { "  (ffprobe absent ou en échec)", "" } }

        -- `:e` relance BufReadCmd: on retire l'ancienne image
        if images[buf] then
            images[buf]:clear()
            images[buf] = nil
        end
        pending[buf] = nil

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

        if info.duration <= 0 then
            return
        end

        -- miniature en cache, invalidée si le fichier change
        local mtime = (vim.uv.fs_stat(file) or {}).mtime or { sec = 0 }
        local thumb = string.format("%s/%s.png", cache_dir, vim.fn.sha256(file .. mtime.sec))
        -- y est indexé à 0: on ancre l'image sur la dernière ligne (vide)
        local y = #info.lines - 1

        if vim.uv.fs_stat(thumb) then
            show_thumb(buf, thumb, y)
            return
        end

        vim.fn.mkdir(cache_dir, "p")
        local job = system(
            thumb_cmd(file, info.duration, thumb),
            {},
            vim.schedule_wrap(function(res)
                if res.code == 0 then
                    show_thumb(buf, thumb, y)
                else
                    vim.notify("Miniature vidéo impossible: " .. (res.stderr or ""), vim.log.levels.WARN)
                end
            end)
        )
        if not job then
            vim.notify("Miniature vidéo impossible: ffmpeg absent", vim.log.levels.WARN)
        end
    end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
        local p = pending[args.buf]
        if p then
            pending[args.buf] = nil
            show_thumb(args.buf, p.thumb, p.y)
        elseif images[args.buf] then
            render(args.buf)
        end
    end,
})

vim.api.nvim_create_autocmd({ "BufWinLeave", "BufWipeout" }, {
    group = group,
    callback = function(args)
        if args.event == "BufWipeout" then
            pending[args.buf] = nil
        end
        local img = images[args.buf]
        if img then
            img:clear()
            if args.event == "BufWipeout" then
                images[args.buf] = nil
            end
        end
    end,
})
