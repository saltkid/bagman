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
	scale = 1.0,
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
---@return string image path to image file
---@return VerticalAlign vertical_align
---@return HorizontalAlign horizontal_align
---@return f32 opacity
---@return Hsb hsb
---@return ObjectFit object_fit
---@return f32 scale
---@return boolean ok successful execution
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
		return "",
			default.vertical_align,
			default.horizontal_align,
			default.opacity,
			default.hsb,
			default.object_fit,
			default.scale,
			false
	end

	local image = images[math.random(#images)]
	return image.path or image,
		image.vertical_align or dir.vertical_align or default.vertical_align,
		image.horizontal_align or dir.horizontal_align or default.horizontal_align,
		image.opacity or dir.opacity or default.opacity,
		image.hsb or dir.hsb or default.hsb,
		image.object_fit or dir.object_fit or default.object_fit,
		image.scale or dir.scale or default.scale,
		true
end

---@param image string | BagmanCleanImage
---@param window_width number window's width in px (`window:get_dimensions().pixel_width`)
---@param window_height number window's height in px (`window:get_dimensions().pixel_height`)
---@param object_fit ObjectFit
---@return number width original image width
---@return number height original image height
---@return number scaled_width scaled image width
---@return number scaled_height scaled image height
---@return bool ok successful execution
local function scale_image(image, window_width, window_height, object_fit)
	local image_width, image_height, err = image_size.size(image.path or image)
	if err then
		wezterm.log_error("BAGMAN ERROR:", err)
		return 0, 0, 0, 0, false
	end

	local scaled_width, scaled_height =
		image_resizer.resize(image_width, image_height, window_width, window_height, image.object_fit or object_fit)
	return image_width, image_height, scaled_width, scaled_height, true
end

-- Set the passed in image and metadata as the background image for the passed in window object.
---@param window Window used to change the background image
---@param image string path to image
---@param image_width number original image width
---@param image_height number original image height
---@param scaled_image_width number
---@param scaled_image_height number
---@param vertical_align string
---@param horizontal_align string
---@param opacity f32
---@param hsb Hsb,
---@param object_fit string for keeping track of object_fit state between window resizes
---@param scale f32
---@param colors? Palette tab line colorscheme
local function set_bg_image(
	window,
	image,
	image_width,
	image_height,
	scaled_image_width,
	scaled_image_height,
	vertical_align,
	horizontal_align,
	opacity,
	hsb,
	object_fit,
	scale,
	colors
)
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
				File = image,
			},
			opacity = opacity,
			height = scaled_image_height * scale,
			width = scaled_image_width * scale,
			vertical_align = vertical_align,
			horizontal_align = horizontal_align,
			hsb = hsb,
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
				scale = default.scale,
				vertical_align = default.vertical_align,
			}
		else
			clean_dirs[i] = {
				horizontal_align = dirty_dir.horizontal_align or default.horizontal_align,
				hsb = dirty_dir.hsb or default.hsb,
				object_fit = dirty_dir.object_fit or default.object_fit,
				opacity = dirty_dir.opacity or default.opacity,
				path = dirty_dir.path,
				scale = dirty_dir.scale or default.scale,
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
				scale = default.scale,
				vertical_align = default.vertical_align,
			}
		else
			clean_images[i] = {
				horizontal_align = dirty_image.horizontal_align or default.horizontal_align,
				hsb = dirty_image.hsb or default.hsb,
				object_fit = dirty_image.object_fit or default.object_fit,
				opacity = dirty_image.opacity or default.opacity,
				path = dirty_image.path,
				scale = dirty_image.scale or default.scale,
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

	-- setup config data with cleaned data
	bagman_data.config = {
		backdrop = clean_backdrop,
		change_tab_colors = opts.change_tab_colors or default.change_tab_colors,
		dirs = clean_dirs,
		images = clean_images,
		interval = opts.interval or default.interval,
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

-- Helper for ze autocomplete. Contains emitters equivalent to:
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

-- Helper for ze autocomplete. Contains emitters equivalent to:
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

	local image, vertical_align, horizontal_align, opacity, hsb, object_fit, scale, ok =
		random_image_from_dirs(bagman_data.config.dirs, bagman_data.config.images)
	if not ok then
		bagman_data.state.retries = bagman_data.state.retries + 1
		return M.emit.next_image(window)
	end

	local window_dims = window:get_dimensions()
	---@diagnostic disable-next-line: redefined-local
	local image_width, image_height, scaled_image_width, scaled_image_height, ok =
		scale_image(image, window_dims.pixel_width, window_dims.pixel_height, object_fit)
	if not ok then
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

	set_bg_image(
		window,
		image,
		image_width,
		image_height,
		scaled_image_width,
		scaled_image_height,
		vertical_align,
		horizontal_align,
		opacity,
		hsb,
		object_fit,
		scale,
		colors
	)
	bagman_data.state.retries = 0
end)

---Sets a specific image as the background image with options to scale and position it
---@param window Window used to change the background image
---@param image string path to image file
---@param opts? BagmanSetImageOptions options to scale and position image
wezterm.on("bagman.set-image", function(window, image, opts)
	opts = opts or {}
	opts.horizontal_align = opts.horizontal_align or default.horizontal_align
	opts.hsb = opts.hsb or default.hsb
	opts.object_fit = opts.object_fit or default.object_fit
	opts.opacity = opts.opacity or default.opacity
	opts.vertical_align = opts.vertical_align or default.vertical_align
	opts.scale = opts.scale or default.scale

	local image_width, image_height = opts.width, opts.height
	if not opts.width or not opts.height then
		local err
		image_width, image_height, err = image_size.size(image)
		if err then
			wezterm.log_error("BAGMAN ERROR:", err)
			return
		end
		local window_dims = window:get_dimensions()
		opts.width, opts.height = image_resizer.resize(
			image_width,
			image_height,
			window_dims.pixel_width,
			window_dims.pixel_height,
			opts.object_fit
		)
	end

	local colors = nil
	if bagman_data.config.change_tab_colors then
		---@type Palette
		colors = {
			tab_bar = colorscheme_builder.build_tab_bar_colorscheme_from_image(image),
		}
	end

	set_bg_image(
		window,
		image,
		image_width,
		image_height,
		opts.width,
		opts.height,
		opts.vertical_align,
		opts.horizontal_align,
		opts.opacity,
		opts.hsb,
		opts.object_fit,
		opts.scale,
		colors
	)
	bagman_data.state.retries = 0
end)

---Recomputes the background image dimensions when resized
---@param window Window used to change the background image
wezterm.on("window-resized", function(window)
	local overrides = window:get_config_overrides() or {}
	local window_dims = window:get_dimensions()
	local new_width, new_height = image_resizer.resize(
		bagman_data.state.current_image.width,
		bagman_data.state.current_image.height,
		window_dims.pixel_width,
		window_dims.pixel_height,
		bagman_data.state.current_image.object_fit
	)
	overrides.background[2].width = new_width * bagman_data.state.current_image.scale
	overrides.background[2].height = new_height * bagman_data.state.current_image.scale
	window:set_config_overrides(overrides)
end)

-- END EVENT HANDLERS }}}

return M
