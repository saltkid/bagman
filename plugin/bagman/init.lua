local wezterm = require("wezterm") --[[@as Wezterm]]
local image_resizer = require("bagman.image-resizer") --[[@as ImageResizer]]
local colorscheme_builder = require("bagman.colorscheme-builder") --[[@as ColorSchemeBuilder]]
local utils = require("bagman.utils") --[[@as BagmanUtils]]

---@class Bagman
local M = {}

---@type BagmanWeztermGlobal
wezterm.GLOBAL.bagman = wezterm.GLOBAL.bagman or {}

-- OPTION DEFAULTS {{{
-- defaults for various bagman data
local default = {
	auto_cycle = true,
	backdrop = { color = "#000000", opacity = 1.0 },
	change_tab_colors = false,
	horizontal_align = "Center",
	hsb = { hue = 1.0, saturation = 1.0, brightness = 1.0 },
	interval = 30 * 60,
	object_fit = "Contain",
	opacity = 1.0,
	vertical_align = "Middle",
}
---}}}

-- STATE VARIABLES {{{

---Defaults
---@type BagmanData
local bagman_data = {
	config = {
		-- Directories where to search for images for. Each directory can also specify options
		-- that will be applied to each image found under it.
		dirs = {},
		-- Image files. Each image can also specify options that will be applied to it.
		images = {},
		-- Interval in seconds on when to trigger a background change.
		interval = default.interval,
		-- Color Layer below the image. Affects the overall tint of the background due to the top
		-- image's opacity.
		backdrop = default.backdrop,
		change_tab_colors = default.change_tab_colors,
		-- contains the experimental options of bagman that may be used by other
		-- modules that may enable/change functionality.
		-- all of the values set here must indicate to not use the feature, aka "off"
		__experimental = {
			contain_fix_wezterm_build = false,
		},
	},
	state = {
		-- Whether to immediately start changing bg image every <interval> seconds. You can trigger
		-- this manually by `wezterm.action.EmitEvent("bagman.start-loop")` or
		-- `bagman.action.start_loop()`. Should only ever have 1 loop. If the event
		-- `bagman.start_loop` gets emitted again, it won't do anything.
		auto_cycle = true,
		-- For limiting repeat triggering `bagman.next-image` event whenever an error is
		-- encountered. Should only be incremented and reset in the 'bagman.next-image' event
		-- handler.
		retries = 0,
	},
}

-- END STATE VARIABLES }}}

-- PRIVATE FUNCTIONS {{{

--- Should only ever have 1 loop. If `bagman.start_loop()` gets called again, it won't do
--- anything.
---@param window Window used to change the background image
local function loop_forever(window)
	if not bagman_data.state.auto_cycle then
		wezterm.log_info("BAGMAN INFO: stopped loop.")
		return
	end
	M.emit.next_image(window)
	wezterm.time.call_after(bagman_data.config.interval, function()
		loop_forever(window)
	end)
end

-- valid filetypes: `*.png, *.jpg, *.jpeg, *.gif, *.bmp, *.ico, *.tiff, *.pnm, *.dds, *.tga, *.farbfeld`
---@param dir string must be absolute path
---@return table<string> images in `dir`
local function images_in_dir(dir)
	local image_types = {
		"*.png",
		"*.jpg",
		"*.jpeg",
		"*.gif",
		"*.bmp",
		"*.ico",
		"*.tiff",
		"*.pnm",
		"*.dds",
		"*.tga",
		"*.farbfeld",
		"*.ff",
	}
	local images = {}
	for _, pattern in ipairs(image_types) do
		local matches = wezterm.glob(dir .. "/" .. pattern)
		for _, file in ipairs(matches) do
			table.insert(images, file)
		end
	end
	return images
end

-- Gets the images in a random directory from `bagman_data.config.dirs`. Also sources
-- `bagman_data.config.images` for images to choose from.
-- Will fail if there are no images found from both images in a dir and `bagman_data.config.images`
---@param dirs table<number, BagmanCleanDir> to get random images from a random dir in dirs
---@param more_images table<number, BagmanCleanImage> additional images to choose from
---@return BagmanImage? image image path with its properties
local function random_image_from_dirs(dirs, more_images)
	---@type table<number, string | BagmanCleanImage>
	local images = {}
	local dir = {}
	if #dirs ~= 0 then
		dir = dirs[math.random(#dirs)]
		images = images_in_dir(dir.path)
	end

	table.move(more_images, 1, #more_images, #images + 1, images)
	if #images == 0 then
		wezterm.log_error("BAGMAN ERROR: no images given by user. Try checking the `dirs` and/or `images` setup option")
		return nil
	end

	local image = images[math.random(#images)]
	return {
		horizontal_align = image.horizontal_align or dir.horizontal_align or default.horizontal_align,
		hsb = image.hsb or dir.hsb or default.hsb,
		object_fit = image.object_fit or dir.object_fit or default.object_fit,
		opacity = image.opacity or dir.opacity or default.opacity,
		path = image.path or image,
		vertical_align = image.vertical_align or dir.vertical_align or default.vertical_align,
	}
end

-- Set the passed in image and metadata as the background image for the passed in window object.
---@param window Window used to change the background image
---@param image BagmanImage image path with its properties
---@param dims { original: ImageDimensions, scaled: ImageDimensions } original image dimensions
---@param colors? Palette tab line colorscheme
local function set_bg_image(window, image, dims, colors)
	local overrides = window:get_config_overrides() or {}
	overrides.colors = colors or overrides.colors
	overrides.background = {
		{
			source = {
				Color = bagman_data.config.backdrop.color,
			},
			opacity = bagman_data.config.backdrop.opacity,
			height = "100%",
			width = "100%",
		},
		{
			source = {
				File = image.path,
			},
			opacity = image.opacity,
			height = dims.scaled.height,
			width = dims.scaled.width,
			vertical_align = image.vertical_align,
			horizontal_align = image.horizontal_align,
			hsb = image.hsb,
			repeat_x = "NoRepeat",
			repeat_y = "NoRepeat",
		},
	}
	window:set_config_overrides(overrides)

	wezterm.GLOBAL.bagman.current_image = {
		height = dims.original.height,
		horizontal_align = image.horizontal_align,
		hsb = image.hsb,
		object_fit = image.object_fit,
		opacity = image.opacity,
		path = image.path,
		vertical_align = image.vertical_align,
		width = dims.original.width,
	}
end

-- END PRIVATE FUNCTIONS }}}

-- EXPORTED MEMBERS {{{

-- Changes background image based on passed in configuration.
-- If `auto_cycle` is true, this will create an event handler during [gui-startup](https://wezfurlong.org/wezterm/config/lua/gui-events/gui-startup.html).
-- If `change_tab_colors` is true, this will change `tab_bar` colors based off of the current image.
---@param opts BagmanSetupOptions
function M.setup(opts)
	if (not opts.dirs or #opts.dirs == 0) and (not opts.images or #opts.images == 0) then
		wezterm.log_error("BAGMAN ERROR: No directories and images provided for background images. args: ", opts)
	end

	-- clean auto_cycle option
	if type(opts.auto_cycle) == "nil" then
		opts.auto_cycle = default.auto_cycle
	end

	-- clean dirs option
	---@type table<number, BagmanCleanDir>
	local clean_dirs = {}
	opts.dirs = opts.dirs or {}
	for i = 1, #opts.dirs do
		local dirty_dir = opts.dirs[i]
		if type(dirty_dir) == "nil" then
			-- continue
		elseif type(dirty_dir) == "string" then
			clean_dirs[i] = {
				horizontal_align = default.horizontal_align,
				hsb = default.hsb,
				object_fit = default.object_fit,
				opacity = default.opacity,
				path = dirty_dir,
				vertical_align = default.vertical_align,
			}
		else
			clean_dirs[i] = {
				horizontal_align = dirty_dir.horizontal_align or default.horizontal_align,
				hsb = dirty_dir.hsb or default.hsb,
				object_fit = dirty_dir.object_fit or default.object_fit,
				opacity = dirty_dir.opacity or default.opacity,
				path = dirty_dir.path,
				vertical_align = dirty_dir.vertical_align or default.vertical_align,
			}
		end
	end

	-- clean images option
	---@type table<number, BagmanCleanImage>
	local clean_images = {}
	opts.images = opts.images or {}
	for i = 1, #opts.images do
		local dirty_image = opts.images[i]
		if type(dirty_image) == "nil" then
			-- continue
		elseif type(dirty_image) == "string" then
			clean_images[i] = {
				horizontal_align = default.horizontal_align,
				hsb = default.hsb,
				object_fit = default.object_fit,
				opacity = default.opacity,
				path = dirty_image,
				vertical_align = default.vertical_align,
			}
		else
			clean_images[i] = {
				horizontal_align = dirty_image.horizontal_align or default.horizontal_align,
				hsb = dirty_image.hsb or default.hsb,
				object_fit = dirty_image.object_fit or default.object_fit,
				opacity = dirty_image.opacity or default.opacity,
				path = dirty_image.path,
				vertical_align = dirty_image.vertical_align or default.vertical_align,
			}
		end
	end

	-- clean backdrop option
	---@type Backdrop
	local clean_backdrop
	if type(opts.backdrop) == "nil" then
		clean_backdrop = default.backdrop
	elseif type(opts.backdrop) == "string" then
		clean_backdrop = {
			color = opts.backdrop --[[@as string]],
			opacity = default.backdrop.opacity,
		}
	else
		clean_backdrop = {
			color = opts.backdrop.color or default.backdrop.color,
			opacity = opts.backdrop.opacity or default.backdrop.opacity,
		}
	end

	-- clean experimental features
	local clean_experimental = bagman_data.config.__experimental
	if opts.experimental then
		for k, v in pairs(opts.experimental or {}) do
			clean_experimental[k] = v
		end
	end

	-- setup config data with cleaned data
	bagman_data.config = {
		backdrop = clean_backdrop,
		change_tab_colors = opts.change_tab_colors or default.change_tab_colors,
		dirs = clean_dirs,
		images = clean_images,
		interval = opts.interval or default.interval,
		__experimental = clean_experimental,
	}
	if opts.auto_cycle then
		bagman_data.state.auto_cycle = true
		wezterm.on("gui-startup", function(cmd)
			local _, _, window = wezterm.mux.spawn_window(cmd or {})
			loop_forever(window:gui_window())
		end)
	else
		bagman_data.state.auto_cycle = false
	end
end

-- current background image set by bagman. changing this won't do anything and
-- is only for reading purposes.
---@return BagmanCurrentImage
function M.current_image()
	return utils.table.deep_copy(wezterm.GLOBAL.bagman.current_image)
end

-- Contains emitters equivalent to:
-- ```lua
-- require("wezterm").emit(--[["some-bagman-event", args if any]])
-- ```
M.emit = {
	-- alias for `wezterm.emit("bagman.next-image", window)`
	---@param window Window used to change the background image
	next_image = function(window)
		wezterm.emit("bagman.next-image", window)
	end,
	-- alias for `wezterm.emit("bagman.set-image", window, image, opts)`
	---@param window Window used to change the background image
	---@param image string path to image file
	---@param opts? BagmanSetImageOptions options to scale and position image
	set_image = function(window, image, opts)
		wezterm.emit("bagman.set-image", window, image, opts)
	end,
	-- alias for `wezterm.emit("bagman.next-image", window)`
	---@param window Window used to change the background image
	start_loop = function(window)
		wezterm.emit("bagman.start-loop", window)
	end,
	-- alias for `wezterm.emit("bagman.stop-loop")`
	stop_loop = function()
		wezterm.emit("bagman.stop-loop")
	end,
}

-- Contains actions equivalent to:
-- ```lua
-- return require("wezterm").action.EmitEvent(--[["some-bagman-event"]])
-- ```
M.action = {
	-- alias for `wezterm.action.EmitEvent("bagman.next-image")`
	---@return KeyAssignment
	next_image = wezterm.action.EmitEvent("bagman.next-image"),
	-- alias for `wezterm.action.EmitEvent("bagman.start-loop")`
	---@return KeyAssignment
	start_loop = wezterm.action.EmitEvent("bagman.start-loop"),
	-- alias for `wezterm.action.EmitEvent("bagman.stop-loop")`
	---@return KeyAssignment
	stop_loop = wezterm.action.EmitEvent("bagman.stop-loop"),
}

--- END EXPORTED FUNCTIONS }}}

-- EVENT HANDLERS {{{

wezterm.on("bagman.start-loop", function(window)
	if bagman_data.state.auto_cycle then
		wezterm.log_error("BAGMAN ERROR: only one bagman loop may exist.")
		return
	end
	bagman_data.state.auto_cycle = true
	loop_forever(window)
end)

wezterm.on("bagman.stop-loop", function()
	if not bagman_data.state.auto_cycle then
		wezterm.log_error("BAGMAN ERROR: no loop is currently running.")
		return
	end
	bagman_data.state.auto_cycle = false
	wezterm.log_info("BAGMAN INFO: stopped signal recieved.")
end)

---Sets a random image as the background image
---@param window Window used to change the background image
wezterm.on("bagman.next-image", function(window)
	if bagman_data.state.retries > 5 then
		wezterm.log_error("BAGMAN ERROR: Too many next-image retries. Exiting...")
		bagman_data.state.retries = 5
		return
	end

	local image = random_image_from_dirs(bagman_data.config.dirs, bagman_data.config.images)
	if not image then
		bagman_data.state.retries = bagman_data.state.retries + 1
		return M.emit.next_image(window)
	end

	local window_dims = window:get_dimensions()
	---@diagnostic disable-next-line: redefined-local
	local image_dims = image_resizer.resize(
		image.path,
		window_dims.pixel_width,
		window_dims.pixel_height,
		image.object_fit,
		bagman_data.config.__experimental.contain_fix_wezterm_build
	)
	if not image_dims then
		bagman_data.state.retries = bagman_data.state.retries + 1
		return M.emit.next_image(window)
	end

	local colors = nil
	if bagman_data.config.change_tab_colors then
		---@type Palette
		colors = {
			tab_bar = colorscheme_builder.build_tab_bar_colorscheme_from_image(image),
		}
	end

	set_bg_image(window, image, image_dims, colors)
	bagman_data.state.retries = 0
end)

---Sets a specific image as the background image with options to scale and position it
---@param window Window used to change the background image
---@param image_path string path to image file
---@param opts? BagmanSetImageOptions options to scale and position image
wezterm.on("bagman.set-image", function(window, image_path, opts)
	opts = opts or {}
	local image = {
		path = image_path,
		horizontal_align = opts.horizontal_align or default.horizontal_align,
		hsb = opts.hsb or default.hsb,
		object_fit = opts.object_fit or default.object_fit,
		opacity = opts.opacity or default.opacity,
		vertical_align = opts.vertical_align or default.vertical_align,
	}

	---@type { original: ImageDimensions, scaled: ImageDimensions }?
	local image_dims
	if not opts.width or not opts.height then
		local window_dims = window:get_dimensions()
		image_dims = image_resizer.resize(
			image_path,
			window_dims.pixel_width,
			window_dims.pixel_height,
			image.object_fit,
			bagman_data.config.__experimental.contain_fix_wezterm_build
		)
		if not image_dims then
			return
		end
	end
	image_dims = image_dims
		or {
			width = opts.width,
			height = opts.height,
			scaled_width = opts.width,
			scaled_height = opts.height,
		}

	local colors = nil
	if bagman_data.config.change_tab_colors then
		---@type Palette
		colors = {
			tab_bar = colorscheme_builder.build_tab_bar_colorscheme_from_image(image),
		}
	end

	set_bg_image(window, image, image_dims, colors)
	bagman_data.state.retries = 0
end)

---Recomputes the background image dimensions when resized
---@param window Window used to change the background image
wezterm.on("window-resized", function(window)
	local overrides = window:get_config_overrides() or {}
	local window_dims = window:get_dimensions()
	local dims = image_resizer.resize(
		wezterm.GLOBAL.bagman.current_image.path,
		window_dims.pixel_width,
		window_dims.pixel_height,
		wezterm.GLOBAL.bagman.current_image.object_fit,
		bagman_data.config.__experimental.contain_fix_wezterm_build
	)
	if not dims then
		return
	end
	overrides.background[2].width = dims.scaled.width
	overrides.background[2].height = dims.scaled.height
	window:set_config_overrides(overrides)
end)

-- END EVENT HANDLERS }}}

return M
