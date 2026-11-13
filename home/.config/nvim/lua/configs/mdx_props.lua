-- MDX: aide à écrire les props des composants, avec mdx-analyzer.
-- Après `<Figure `, les props pas encore écrites s'affichent en texte fantôme jusqu'à la
-- frappe suivante. <Tab> / <S-Tab> en sélectionnent une et montrent sa doc, <CR> l'écrit
-- (touches définies dans plugins/completion.lua).
-- Sur un nom de prop complet, sa doc reste affichée jusqu'au `=`.

local M = {}

-- fichier du blog (projet Astro) qui déclare les composants et le type de leurs props
local PROPS_FILE = "src/components/blog/props.ts"

local ns = vim.api.nvim_create_namespace "mdx_props"
local props_cache = {} -- "id du client:composant" -> { { name, label, item } }
local failed = {} -- "id du client:composant" -> vim.uv.now() après 5 essais sans props
local FAILED_TTL = 10000 -- ms avant de redemander un composant en échec
local state = {} -- buf -> { tick, win, doc_key, ghost, last }

-- Cache vidé quand le code des composants a pu changer: enregistré dans nvim, ou modifié
-- ailleurs (git pull dans un terminal) avant de revenir dans nvim
local function reset_cache()
    props_cache, failed = {}, {}
end
vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("MdxPropsCache", { clear = true }),
    pattern = { "*.ts", "*.tsx", "*.astro" },
    callback = reset_cache,
})
vim.api.nvim_create_autocmd("FocusGained", { group = "MdxPropsCache", callback = reset_cache })

local function mdx_client(buf)
    return vim.lsp.get_clients({ bufnr = buf, name = "mdx_analyzer" })[1]
end

-- Balise ouverte sous le curseur: nom du composant, attributs déjà écrits, et où on en est
-- (mode: "tagname", "space", "name" ou "value")
local function parse_tag(buf, row, col)
    local lines = vim.api.nvim_buf_get_lines(buf, math.max(0, row - 10), row + 1, false)
    lines[#lines] = lines[#lines]:sub(1, col)
    local text = table.concat(lines, "\n")

    local start, name
    for s, n in text:gmatch "()<(%u[%w.]*)" do
        start, name = s, n
    end
    if not start then
        return nil
    end

    local inner = text:sub(start + #name + 1)
    if inner == "" then
        return { name = name, mode = "tagname", present = {} }
    end
    local stripped = inner:gsub('"[^"]*"', '""'):gsub("{[^{}]*}", "{}")
    if stripped:find ">" then
        return nil
    end

    local tag = { name = name, present = {} }
    if select(2, stripped:gsub('"', "")) % 2 == 1 or stripped:find "{[^}]*$" or stripped:find "=%s*$" then
        tag.mode = "value"
    elseif stripped:find "%s$" then
        tag.mode = "space"
    else
        tag.mode = "name"
        tag.word = stripped:match "[%w_-]+$"
    end
    for attr in stripped:gmatch "[%a_][%w_-]*" do
        tag.present[attr] = true
    end
    return tag
end

local function position(buf, row, col)
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    return {
        textDocument = { uri = vim.uri_from_bufnr(buf) },
        position = { line = row, character = vim.str_utfindex(line, "utf-16", col, false) },
    }
end

-- une clé par serveur, deux projets peuvent avoir un composant du même nom
local function cache_key(client, name)
    return client.id .. ":" .. name
end

local function fetch_props(buf, client, row, col, name, callback, on_fail)
    local key = cache_key(client, name)
    if props_cache[key] then
        return callback(props_cache[key])
    end
    -- composant sans props ou inconnu: on ne redemande pas à chaque frappe
    if failed[key] and vim.uv.now() - failed[key] < FAILED_TTL then
        return
    end
    local params = position(buf, row, col)
    params.context = { triggerKind = 1 }
    client:request("textDocument/completion", params, function(err, result)
        if err or not result then
            return on_fail()
        end
        local props, seen = {}, {}
        for _, item in ipairs(result.items or result) do
            local prop = item.label:gsub("%?$", "")
            local is_field = item.kind == 5 or item.kind == 10
            -- un nom en majuscule est un composant: la requête est tombée sur le nom de balise
            if is_field and prop:match "^%u" then
                return on_fail()
            end
            if is_field and not seen[prop] and not prop:match "^_" and prop ~= "children" and prop ~= "slot" then
                seen[prop] = true
                table.insert(props, { name = prop, label = item.label, item = item })
            end
        end
        if #props == 0 then
            -- si la réponse n'est pas vide, le serveur est prêt et le composant n'a pas de props
            return on_fail(#(result.items or result) > 0)
        end
        props_cache[key] = props
        callback(props)
    end, buf)
end

-- Noms des props d'un composant d'après PROPS_FILE, nil si le composant est inconnu
local props_ts = {}
function M.prop_names(buf, name)
    local root = vim.fs.root(buf, { "astro.config.mjs", "astro.config.ts", "astro.config.js" })
    if not root then
        return nil
    end
    local path = root .. "/" .. PROPS_FILE
    local stat = vim.uv.fs_stat(path)
    if not stat then
        return nil
    end
    if props_ts.path ~= path or props_ts.mtime ~= stat.mtime.sec then
        local text = table.concat(vim.fn.readfile(path), "\n")
        local types = {}
        for typ, body in text:gmatch "export interface (%w+) {(.-)\n}" do
            local set = {}
            for prop in body:gmatch "\n%s+([%a_][%w_]*)%??:" do
                set[prop] = true
            end
            types[typ] = set
        end
        local names = {}
        for comp, typ in text:gmatch "\n%s+(%u%w*): Component<(%w+)>" do
            names[comp] = types[typ] or {}
        end
        props_ts.path, props_ts.mtime, props_ts.names = path, stat.mtime.sec, names
    end
    return props_ts.names[name]
end

local function close_doc(s)
    if s.win and vim.api.nvim_win_is_valid(s.win) then
        vim.api.nvim_win_close(s.win, true)
    end
    s.win, s.doc_key = nil, nil
end

local function clear(buf)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

local function open_doc(s, lines)
    close_doc(s)
    local _, win = vim.lsp.util.open_floating_preview(lines, "markdown", {
        focusable = false,
        close_events = {},
        border = "rounded",
        max_width = 80,
        anchor_bias = "above",
    })
    s.win = win
end

local function render_ghost(buf, ghost)
    clear(buf)
    local chunks = { { ghost.prefix, "Comment" } }
    for i, p in ipairs(ghost.props) do
        if i > 1 then
            table.insert(chunks, { "  ", "Comment" })
        end
        table.insert(chunks, { p.label, i == ghost.sel and "PmenuSel" or "Comment" })
    end
    if ghost.prefix == "" then
        table.insert(chunks, { " ", "Comment" })
    end
    vim.api.nvim_buf_set_extmark(buf, ns, ghost.row, ghost.col, { virt_text = chunks, virt_text_pos = "inline" })
end

local function show_ghost(buf, s, row, col, tag, props, prefix)
    local remaining = {}
    for _, p in ipairs(props) do
        if not tag.present[p.name] then
            table.insert(remaining, p)
        end
    end
    clear(buf)
    s.ghost = nil
    if #remaining == 0 then
        return
    end
    s.ghost = { row = row, col = col, prefix = prefix, props = remaining }
    render_ghost(buf, s.ghost)
end

-- Exemple de valeur d'après le type: le premier littéral qui n'est pas la valeur par défaut,
-- sinon une valeur selon le type
local function example(name, detail, doc)
    local typ = detail:match "%?*: (.*)$" or ""
    local default = doc:match "%*@default%*%s*```%s*(.-)%s*```"
    for literal in typ:gmatch '"[^"]*"' do
        if literal ~= default then
            return name .. "=" .. literal
        end
    end
    if typ == "boolean" then
        return default == "true" and name .. "={false}" or name
    end
    if typ == "number" then
        return name .. "={1}"
    end
    if typ == "string" then
        return name .. '="…"'
    end
    return name .. "={…}"
end

local function show_ghost_doc(buf, s, p)
    local client = mdx_client(buf)
    if not client then
        return
    end
    local tick = s.tick
    client:request("completionItem/resolve", p.item, function(err, item)
        if err or not item or state[buf] ~= s or s.tick ~= tick then
            return
        end
        local detail = item.detail or ""
        local doc = type(item.documentation) == "table" and item.documentation.value or item.documentation or ""
        local lines = { "```typescript", detail, "```", "" }
        vim.list_extend(lines, vim.split(doc, "\n"))
        if not doc:find "@example" then
            vim.list_extend(lines, { "", "**Exemple**: `" .. example(p.name, detail, doc) .. "`" })
        end
        open_doc(s, lines)
    end, buf)
end

local function show_doc(buf, client, s, row, col, tag)
    local key = tag.name .. "." .. tag.word
    if s.doc_key == key and s.win and vim.api.nvim_win_is_valid(s.win) then
        return
    end
    close_doc(s)
    s.doc_key = key
    local tick = s.tick
    client:request("textDocument/hover", position(buf, row, col - #tag.word), function(err, result)
        if err or not result or state[buf] ~= s or s.tick ~= tick or vim.api.nvim_get_mode().mode ~= "i" then
            return
        end
        local value = type(result.contents) == "table" and result.contents.value or nil
        if value then
            open_doc(s, vim.split(value, "\n"))
        end
    end, buf)
end

local function update(buf, retry)
    local s = state[buf]
    s.tick = s.tick + 1
    s.retry = retry or 0
    s.ghost = nil
    clear(buf)

    local client = mdx_client(buf)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1
    local tag = client and parse_tag(buf, row, col)
    if not tag or tag.mode == "value" then
        return close_doc(s)
    end

    -- juste après le nom, on interroge le serveur après l'espace du ` />` ajouté
    local line = vim.api.nvim_get_current_line()
    if tag.mode == "tagname" and line:sub(col + 1, col + 1) ~= " " then
        return close_doc(s)
    end
    local query_col = tag.mode == "tagname" and col + 1 or col

    local tick = s.tick
    fetch_props(buf, client, row, query_col, tag.name, function(props)
        if state[buf] ~= s or s.tick ~= tick then
            return
        end
        if tag.mode == "tagname" or tag.mode == "space" then
            close_doc(s)
            return show_ghost(buf, s, row, col, tag, props, tag.mode == "tagname" and " " or "")
        end
        for _, p in ipairs(props) do
            if p.name == tag.word then
                return show_doc(buf, client, s, row, col, tag)
            end
        end
        close_doc(s)
    end, function(no_props)
        -- Réponse vide: le serveur démarre encore, on redemande un peu plus tard.
        -- Après 5 essais, si le serveur a répondu, c'est que le composant n'a pas de props.
        if s.retry >= 5 then
            if no_props then
                failed[cache_key(client, tag.name)] = vim.uv.now()
            end
        else
            vim.defer_fn(function()
                if state[buf] == s and s.tick == tick and vim.api.nvim_get_mode().mode == "i" then
                    update(buf, s.retry + 1)
                end
            end, 300)
        end
    end)
end

local function current_ghost()
    local s = state[vim.api.nvim_get_current_buf()]
    local ghost = s and s.ghost
    if not ghost then
        return nil
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if row - 1 ~= ghost.row or col ~= ghost.col then
        return nil
    end
    return s, ghost
end

-- Y a-t-il des props fantômes sous le curseur (et, avec selected, l'une est-elle sélectionnée) ?
-- blink.cmp appelle ses touches dans un mapping <expr>, où on ne peut ni modifier le texte ni
-- fermer une fenêtre (E565). Les touches testent donc ici, puis lancent select / accept dans un
-- vim.schedule.
function M.has_ghost(selected)
    local _, ghost = current_ghost()
    return ghost ~= nil and (not selected or ghost.sel ~= nil)
end

-- Sélectionne la prop suivante (dir = 1) ou précédente (dir = -1), false s'il n'y en a pas
function M.select(dir)
    local s, ghost = current_ghost()
    if not ghost then
        return false
    end
    local n = #ghost.props
    ghost.sel = ghost.sel and ((ghost.sel - 1 + dir) % n) + 1 or (dir > 0 and 1 or n)
    if package.loaded["blink.cmp"] then
        require("blink.cmp").hide()
    end
    render_ghost(vim.api.nvim_get_current_buf(), ghost)
    show_ghost_doc(vim.api.nvim_get_current_buf(), s, ghost.props[ghost.sel])
    return true
end

-- Écrit la prop sélectionnée, false si aucune ne l'est
function M.accept()
    local s, ghost = current_ghost()
    if not ghost or not ghost.sel then
        return false
    end
    local item = ghost.props[ghost.sel].item
    local text = (item.insertText or item.label:gsub("%?$", "")):gsub("'", '"')
    if ghost.prefix ~= "" then
        -- juste après le nom, on écrit après l'espace du ` />`
        vim.api.nvim_win_set_cursor(0, { ghost.row + 1, ghost.col + 1 })
    end
    clear(vim.api.nvim_get_current_buf())
    close_doc(s)
    s.ghost = nil
    if item.insertTextFormat == 2 then
        vim.snippet.expand(text .. " $0")
    else
        vim.api.nvim_put({ text .. " " }, "c", false, true)
    end
    return true
end

function M.attach(buf)
    if state[buf] then
        return
    end
    state[buf] = { tick = 0 }
    local group = vim.api.nvim_create_augroup("MdxProps" .. buf, { clear = true })

    vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI", "InsertEnter" }, {
        group = group,
        buffer = buf,
        callback = function()
            -- une frappe déclenche CursorMovedI et TextChangedI, on ne met à jour qu'une fois
            local s = state[buf]
            local cursor = vim.api.nvim_win_get_cursor(0)
            local key = vim.b[buf].changedtick .. ":" .. cursor[1] .. ":" .. cursor[2]
            if s.last == key then
                return
            end
            s.last = key
            update(buf)
        end,
    })
    vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
        group = group,
        buffer = buf,
        callback = function()
            state[buf].tick = state[buf].tick + 1
            state[buf].last = nil
            clear(buf)
            close_doc(state[buf])
        end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = buf,
        callback = function()
            state[buf] = nil
        end,
    })
end

return M
