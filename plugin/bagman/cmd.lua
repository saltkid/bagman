local wezterm = require("wezterm") --[[@as Wezterm]]

---@class OSUtils
local M = {}

---@param name "windows" | "apple" | "linux"
---@return boolean
function M.platform_is(name)
	return string.find(wezterm.target_triple, name) ~= nil
end

---@param opts {linux: table<number, string>?, macos: table<number, string>?, windows: table<number, string>?}
---@return string? result
function M.exec(opts)
	local command = {}
	if M.platform_is("linux") then
		command = opts.linux or {}
	elseif M.platform_is("apple") then
		command = opts.macos or {}
	elseif M.platform_is("windows") then
		command = opts.windows or {}
	else
		wezterm.log_error("BAGMAN CMD ERROR: Failed to execute command. Unknown OS:", wezterm.target_triple)
		return nil
	end
	local success, stdout, stderr = wezterm.run_child_process(command)
	if not success then
		wezterm.log_error("BAGMAN CMD ERROR: Failed to execute command: ", table.concat(command, ""), "error:", stderr)
		return nil
	end
	return stdout
end

---@param opts {linux: string?, macos: string?, windows: string?}
---@return boolean ok is executable?
function M.is_executable(opts)
	if M.platform_is("linux") then
		if not opts.linux then
			wezterm.log_error("BAGMAN CMD ERROR: No command given for linux to execute")
			return false
		end
		local handle = io.popen("which " .. opts.linux .. " 2>/dev/null")
		if not handle then
			wezterm.log_error("BAGMAN CMD ERROR: Failed to execute 'which'")
			return false
		end
		local result = handle:read("*a")
		handle:close()
		return result ~= opts.linux .. " not found"
	elseif M.platform_is("apple") then
		if not opts.macos then
			wezterm.log_error("BAGMAN CMD ERROR: No command given for macos to execute")
			return false
		end
		local handle = io.popen("which " .. opts.macos .. " 2>/dev/null")
		if not handle then
			wezterm.log_error("BAGMAN CMD ERROR: Failed to execute 'which'")
			return false
		end
		local result = handle:read("*a")
		handle:close()
		return result ~= opts.macos .. " not found"
	elseif M.platform_is("windows") then
		if not opts.windows then
			wezterm.log_error("BAGMAN CMD ERROR: No command given for windows to execute")
			return false
		end
		local handle = io.popen("where " .. opts.windows .. " 2>NUL")
		if not handle then
			wezterm.log_error("BAGMAN CMD ERROR: Failed to execute 'where'")
			return false
		end
		local result = handle:read("*a")
		handle:close()
		return result ~= ""
	else
		wezterm.log_error("BAGMAN CMD ERROR: Failed to execute command:", opts.windows, "; unknown OS")
		return false
	end
end

return M
