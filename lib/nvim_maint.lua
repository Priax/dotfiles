-- Lancé par nvim_maint (lib/nvim.sh) dans nvim --headless.
-- DOT_NVIM: install, upgrade, list ou remove. DOT_NVIM_LIST: fichier de la liste (list, remove).

local mode = vim.env.DOT_NVIM
local list_file = vim.env.DOT_NVIM_LIST

local MINUTE = 60000

local function say(m)
	io.stdout:write("  " .. m .. "\n")
	io.stdout:flush()
end

local had_error = false

local function report(m)
	had_error = true
	say(m)
end

local function wait_for(timeout, done)
	return vim.wait(timeout, done, 500)
end

local function treesitter_spec()
	return require("lazy.core.config").plugins["nvim-treesitter"]
end

local function ensure_installed()
	local values = require("lazy.core.plugin").values
	local opts = values(treesitter_spec(), "opts", false)

	return opts.ensure_installed or {}
end

local function check_plugins()
	local Plugin = require("lazy.core.plugin")

	for name, plugin in pairs(require("lazy.core.config").plugins) do
		if Plugin.has_errors(plugin) then
			report("échec du plugin " .. name)
		end
	end
end

local function mason_ready()
	local mr = require("mason-registry")
	local refreshed = false

	mr.refresh(function()
		refreshed = true
	end)

	vim.wait(2 * MINUTE, function()
		return refreshed
	end, 200)

	return mr
end

local function wanted_parsers()
	local parsers = require("nvim-treesitter.parsers")
	local wanted = {}

	local function want(lang)
		if wanted[lang] then
			return
		end

		wanted[lang] = true

		local requires = parsers[lang] and parsers[lang].requires or {}
		for _, dep in ipairs(requires) do
			want(dep)
		end
	end

	for _, lang in ipairs(ensure_installed()) do
		want(lang)
	end

	return wanted
end

local function wanted_mason(mr)
	local keep = {}

	for _, name in ipairs(require("configs.mason").wanted()) do
		keep[name:match("^[^@]+")] = true
	end

	local enabled = vim.lsp._enabled_configs or {}

	for _, pkg in ipairs(mr.get_installed_packages()) do
		local lsp = pkg.spec.neovim and pkg.spec.neovim.lspconfig
		if lsp and enabled[lsp] then
			keep[pkg.name] = true
		end
	end

	return keep
end

local function run_all(jobs)
	local pending = #jobs

	for _, job in ipairs(jobs) do
		job(function(success, err)
			if not success then
				report("échec: " .. tostring(err))
			end
			pending = pending - 1
		end)
	end

	local finished = wait_for(30 * MINUTE, function()
		return pending == 0
	end)

	if not finished then
		report("paquets Mason: délai dépassé")
	end
end

local function sync_plugins(lazy)
	local opts = { wait = true, show = false }

	if mode == "install" then
		say("plugins (lazy-lock.json)...")
		lazy.restore(opts)
	elseif mode == "upgrade" then
		say("plugins (lazy sync)...")
		lazy.sync(opts)
	elseif mode == "list" then
		say("plugins retirés de la config (lazy clean)...")
		lazy.clean(opts)
	end

	check_plugins()
end

local function install_missing_parsers(ts)
	local installed = ts.get_installed()

	local missing = vim.tbl_filter(function(lang)
		return not vim.tbl_contains(installed, lang)
	end, ensure_installed())

	if #missing == 0 then
		return 0
	end

	say("parsers treesitter manquants: " .. table.concat(missing, ", "))

	local installed_all = ts.install(missing):wait(15 * MINUTE)
	io.stdout:write("\n")

	if not installed_all then
		report("échec de l'installation de parsers treesitter")
	end

	return #missing
end

local function install_missing_mason()
	local failed = nil
	local started = 0

	local function on_done(f)
		failed = f
	end

	local function on_start(name)
		started = started + 1
		say("Mason: installation de " .. name)
	end

	require("configs.mason").install_all(on_done, on_start)

	local finished = wait_for(30 * MINUTE, function()
		return failed ~= nil
	end)

	if not finished then
		report("paquets Mason: délai dépassé")
	end

	for _, line in ipairs(failed or {}) do
		report("échec Mason " .. line)
	end

	return started
end

local function install_missing(ts)
	local parsers = install_missing_parsers(ts)
	local packages = install_missing_mason()

	if parsers == 0 and packages == 0 then
		say("parsers et paquets Mason: rien ne manque")
	end
end

local function upgrade_all(ts, mr)
	say("mise à jour des parsers treesitter...")
	if not ts.update():wait(10 * MINUTE) then
		report("échec de la mise à jour de parsers treesitter")
	end

	local jobs = {}

	for _, pkg in ipairs(mr.get_installed_packages()) do
		local current = pkg:get_installed_version()
		local latest = pkg:get_latest_version()

		if current ~= latest then
			say(("Mason %s: %s → %s"):format(pkg.name, current or "?", latest))

			jobs[#jobs + 1] = function(done)
				pkg:install({}, done)
			end
		end
	end

	run_all(jobs)
end

local function write_unused_list(ts, mr)
	local parsers = wanted_parsers()
	local keep = wanted_mason(mr)
	local lines = {}

	for _, lang in ipairs(ts.get_installed()) do
		if not parsers[lang] then
			lines[#lines + 1] = "parser " .. lang
		end
	end

	for _, pkg in ipairs(mr.get_installed_packages()) do
		if not keep[pkg.name] then
			lines[#lines + 1] = "mason " .. pkg.name
		end
	end

	vim.fn.writefile(lines, list_file)
end

local function remove_listed(ts, mr)
	local langs = {}
	local jobs = {}

	for _, line in ipairs(vim.fn.readfile(list_file)) do
		local kind, name = line:match("^(%S+) (%S+)$")

		if kind == "parser" then
			langs[#langs + 1] = name
		elseif kind == "mason" and mr.is_installed(name) then
			jobs[#jobs + 1] = function(done)
				mr.get_package(name):uninstall({}, done)
			end
		end
	end

	if #langs > 0 then
		ts.uninstall(langs):wait(MINUTE)
	end

	run_all(jobs)
end

local function main()
	local lazy = require("lazy")

	sync_plugins(lazy)
	lazy.load({ plugins = { "nvim-lspconfig", "conform.nvim", "mason.nvim", "nvim-treesitter" } })

	local ts = require("nvim-treesitter")
	local mr = mason_ready()

	if mode == "install" or mode == "upgrade" then
		install_missing(ts)
	end

	if mode == "upgrade" then
		upgrade_all(ts, mr)
	elseif mode == "list" then
		write_unused_list(ts, mr)
	elseif mode == "remove" then
		remove_listed(ts, mr)
	end
end

local ok, err = xpcall(main, debug.traceback)

if not ok then
	report("erreur: " .. err)
end

vim.cmd(had_error and "cq" or "qa!")
