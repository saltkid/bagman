local wezterm = require("wezterm") --[[@as Wezterm]]

---@class ColorSchemeBuilder
local M = {}

---Calculates luminance of color. Bright colors are those with luminance of >0.5
---@param color Color
---@return boolean
local function is_bright(color)
	local r, g, b, _ = color:srgba_u8()
	r = math.max(0, math.min(255, r))
	g = math.max(0, math.min(255, g))
	b = math.max(0, math.min(255, b))
	local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
	return (luminance / 255) > 0.5
end

---Change the brightness value of a `to_change` based on the brightness of `basis`
---@param basis Color basis of brightness
---@param to_change Color color being brightened/darkened
---@return Color color2
local function increase_contrast(to_change, basis)
	return is_bright(basis) and to_change:darken(0.75) or to_change:lighten(0.75)
end

---Exaggerates the brightness value of a color. This means that if a color is already bright, the
---returned color will be a brighter version of it. If the color is already dark, the returned
---color will be a darker version of it
---@param color Color color being brightened/darkened
---@return Color color2
local function exaggerate_brightness(color)
	return is_bright(color) and color:lighten(0.25) or color:darken(0.25)
end

-- Returns a color scheme for tab line based on an image file's colors
-- Color picking is based on Kanagawa Dragon's structure, not just randomly/different for each
-- category. The rules goes as follows:
-- * most dominant color is the color for tab_bar.background and all fg_color
-- * new_tab_hover's and inactive_tab_hover's bg_color are the same color
-- * the rest can be different
---@param image string | { path: string, speed: number } path to image file
---@return TabBar color_scheme tab bar color scheme
function M.build_tab_bar_colorscheme_from_image(image)
	---@type table<number, Color>
	local color_from_image = wezterm.color.extract_colors_from_image(image.path or image, {
		-- only need 4 for tab_bar config. might add more if this is expanded (probably not)
		num_colors = 4,
		-- has good enough results from my testing
		-- feel free to keep it at 100 to ensure different colors
		threshold = 100,
	})
	---@type TabBar
	return {
		background = color_from_image[1],
		active_tab = {
			bg_color = exaggerate_brightness(color_from_image[2]),
			fg_color = increase_contrast(color_from_image[1], color_from_image[2]),
		},
		inactive_tab = {
			bg_color = exaggerate_brightness(color_from_image[3]),
			fg_color = increase_contrast(color_from_image[1], color_from_image[3]),
		},
		new_tab = {
			bg_color = exaggerate_brightness(color_from_image[3]),
			fg_color = increase_contrast(color_from_image[1], color_from_image[3]),
		},
		new_tab_hover = {
			bg_color = exaggerate_brightness(color_from_image[4]),
			fg_color = increase_contrast(color_from_image[1], color_from_image[4]),
			italic = true,
		},
		inactive_tab_hover = {
			bg_color = exaggerate_brightness(color_from_image[4]),
			fg_color = increase_contrast(color_from_image[1], color_from_image[4]),
			italic = true,
		},
	}
end

return M
