local wezterm = require("wezterm") --[[@as Wezterm]]

-- MAKE SUBMODULES REQUIREABLE {{{
-- Thanks to all the wezterm plugin maintainers for pointing me in the right direction.
-- :3

local is_windows = string.match(wezterm.target_triple, "windows") ~= nil
local separator = is_windows and "\\" or "/"
local plugin_dir = wezterm.plugin.list()[1].plugin_dir:gsub(separator .. "[^" .. separator .. "]*$", "")

local function directory_exists(path)
	local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
	return success and result
end

local function get_require_path()
	local path = "httpssCssZssZsgithubsDscomsZssaltkidsZsbagman"
	local trailing_slash = path .. "sZs"
	return directory_exists(trailing_slash) and trailing_slash or path
end

package.path = package.path
	.. ";"
	.. plugin_dir
	.. separator
	.. get_require_path()
	.. separator
	.. "plugin"
	.. separator
	.. "?.lua"
	.. ";"
	.. plugin_dir
	.. separator
	.. get_require_path()
	.. separator
	.. "plugin"
	.. separator
	.. "?"
	.. separator
	.. "init.lua"

-- }}}

---@class Bagman
local bagman = require("bagman")

-- not doing anything to the config right now
function bagman.apply_to_config(config, opts)
	return config
end

return bagman
