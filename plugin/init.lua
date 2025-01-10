local wezterm = require("wezterm") --[[@as Wezterm]]

-- MAKE THIS PLUGIN'S SUBMODULES REQUIREABLE {{{
-- Thanks to all the wezterm plugin maintainers for pointing me in the right
-- direction :3

local is_windows = string.match(wezterm.target_triple, "windows") ~= nil
local separator = is_windows and "\\" or "/"
local plugin_dir = wezterm.plugin
    .list()[1].plugin_dir
    :gsub(separator .. "[^" .. separator .. "]*$", "")

local function directory_exists(path)
    local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
    return success and result
end

local url = "https://github.com/saltkid/bagman"
local path = url:gsub("[:/%.]", {
    [":"] = "sCs",
    ["/"] = "sZs",
    ["."] = "sDs",
})
local with_trailing_slash = path .. "sZs"
local require_path = directory_exists(with_trailing_slash)
        and with_trailing_slash
    or path

package.path = package.path
    .. ";"
    -- for file submodules
    .. plugin_dir
    .. separator
    .. require_path
    .. separator
    .. "plugin"
    .. separator
    .. "?.lua"
    .. ";"
    -- for directory submodules
    .. plugin_dir
    .. separator
    .. require_path
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
