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
	return width, height, true
end

---Computes the `contain` width and height of an image using current window width and height as
---basis.
---Simulates css's `object-fit: contain` where the image keeps its aspect ratio, but is resized to
---fit within the given window dimensions. This is unlike `cover` where the image keeps its aspect
---ratio and fills the given dimension but will be clipped to fit
---@param width number width of image to scale
---@param height number height of image to scale
---@param windowWidth number width of current window
---@param windowHeight number height of current window
---@return number width
---@return number height
function M.contain_dimensions(width, height, windowWidth, windowHeight)
	local ratio = width / height
	local width_val = 0
	local height_val = 0
	if ratio > 1 then
		width_val = windowWidth
		height_val = math.floor(windowWidth / ratio)
	else
		width_val = math.floor(ratio * windowHeight)
		height_val = windowHeight
	end
	return width_val, height_val
end

return M
