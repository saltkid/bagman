local wezterm = require("wezterm") --[[@as Wezterm]]
local cmd = require("bagman.cmd") --[[@as OSUtils]]

---@class ImageHandler
local M = {}

---Gets the dimensions of the passed in image using `identify` from ImageMagick
---@param image string path to image file
---@return number width
---@return number height
---@return boolean ok successful execution
function M.dimensions(image)
	if not cmd.is_executable({
		linux = "identify",
		macos = "magick",
		windows = "magick",
	}) then
		return 0, 0, false
	end
	local res = cmd.exec({
		linux = { "identify", "-format", "%w %h", image },
		macos = { "magick", "identify", "-format", "%w %h", image },
		windows = { "magick", "identify", "-format", "%w %h", image },
	})
	if not res then
		wezterm.log_error("Failed to get dimensions of image:", image, "; Result is nil:", res)
		return 0, 0, false
	end
	local wh = res:match("^(%d+) (%d+)")
	if not wh then
		wezterm.log_error(
			"Failed to get dimensions of image:",
			image,
			"; Did not get width and height from result:",
			res
		)
		return 0, 0, false
	end
	local width, height = res:match("^(%d+) (%d+)")
	local width_num = tonumber(width)
	local height_num = tonumber(height)
	if not width_num or not height_num then
		wezterm.log_error("BAGMAN IMAGE HANDLER ERROR: Failed to convert to number:", width, height)
		return 0, 0, false
	end
	return width_num, height_num, true
end

---Returns the resized dimensions of an image based on the specified object_fit strategy
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@param object_fit "Contain" | "Cover" | "Fill"
---@return number new_width
---@return number new_height
function M.resize_image(image_width, image_height, window_width, window_height, object_fit)
	if "Contain" == object_fit then
		local new_width, new_height = M.contain_dimensions(image_width, image_height, window_width, window_height)
		return new_width, new_height
	elseif "Cover" == object_fit then
		local new_width, new_height = M.cover_dimensions(image_width, image_height, window_width, window_height)
		return new_width, new_height
	elseif "Fill" == object_fit then
		return window_width, window_height
	else
		wezterm.log_error("BAGMAN IMAGE HANDLER ERROR: unknown object_fit:", object_fit)
		return image_width, image_height
	end
end

---Computes css's `object-fit: contain` width and height of an image using current window width and
---height as basis.
---Simulates css's `object-fit: contain` where the image keeps its aspect ratio, but is resized to
---fit within the given window dimensions.
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@return number width
---@return number height
function M.contain_dimensions(image_width, image_height, window_width, window_height)
	if image_width > image_height then
		return window_width, math.floor(window_width * image_height / image_width)
	else
		return math.floor(window_height * image_width / image_height), window_height
	end
end

---Computes css's `object-fit: cover` width and height of an image using current window width and
---height as basis.
---This can already be done in wezterm by doing "Cover" on whichever dimension is smaller and nil
---on the other. This is just implemented again to stay consisten with other object_fits working
---with numbers
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@return number width
---@return number height
function M.cover_dimensions(image_width, image_height, window_width, window_height)
	if image_width > image_height then
		return math.floor(window_height * image_width / image_height), window_height
	else
		return window_width, math.floor(window_width * image_height / image_width)
	end
end

return M
