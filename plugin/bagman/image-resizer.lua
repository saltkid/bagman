local wezterm = require("wezterm") --[[@as Wezterm]]

---@class ImageResizer
local M = {}

---Returns the resized dimensions of an image based on the specified object_fit strategy
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@param object_fit "Contain" | "Cover" | "Fill"
---@return number new_width
---@return number new_height
function M.resize(image_width, image_height, window_width, window_height, object_fit)
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
