local wezterm = require("wezterm") --[[@as Wezterm]]
local image_size = require("bagman.image-size") --[[@as ImageSize]]
local image_resizer = require("bagman.image-resizer") --[[@as ImageResizer]]
local colorscheme_builder = require("bagman.colorscheme-builder") --[[@as ColorSchemeBuilder]]

---@class Bagman
local M = {}

-- OPTION DEFAULTS {{{
-- defaults for various bagman data
local default = {
	interval = 30 * 60,
	backdrop = "#000000",
	change_tab_colors = false,
	is_looping = true,
	vertical_align = "Middle",
	horizontal_align = "Center",
	object_fit = "Contain",
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
		is_looping = true,
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
	if not bagman_data.state.is_looping then
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
---@return "Top" | "Middle" | "Bottom" vertical_align
---@return "Left" | "Center" | "Right" horizontal_align
---@return "Contain" | "Cover" | "Fill" object_fit
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
		return "", default.vertical_align, default.horizontal_align, default.object_fit, false
	end

	local image = images[math.random(#images)]
	return image.path or image,
		image.vertical_align or dir.vertical_align or default.vertical_align,
		image.horizontal_align or dir.horizontal_align or default.horizontal_align,
		image.object_fit or dir.object_fit or default.object_fit,
		true
end

---@param image string | BagmanCleanImage
---@param window_width number window's width in px (`window:get_dimensions().pixel_width`)
---@param window_height number window's height in px (`window:get_dimensions().pixel_height`)
---@param object_fit "Contain" | "Cover" | "Fill"
---@return number width image width
---@return number height image height
---@return bool ok successful execution
local function scale_image(image, window_width, window_height, object_fit)
	local image_width, image_height, err = image_size.size(image.path or image)
	if err then
		wezterm.log_info(err)
		return 0, 0, false
	end

	local scaled_width, scaled_height =
		image_resizer.resize(image_width, image_height, window_width, window_height, image.object_fit or object_fit)
	return scaled_width, scaled_height, true
end

-- Set the passed in image and metadata as the background image for the passed in window object.
---@param window Window used to change the background image
---@param image string path to image
---@param image_width number
---@param image_height number
---@param vertical_align string
---@param horizontal_align string
---@param colors? Palette tab line colorscheme
local function set_bg_image(window, image, image_width, image_height, vertical_align, horizontal_align, colors)
	local overrides = window:get_config_overrides() or {}
	overrides.colors = colors or overrides.colors
	overrides.background = {
		{
			source = {
				Color = bagman_data.config.backdrop,
			},
			opacity = 0.95,
			height = "100%",
			width = "100%",
		},
		{
			source = {
				File = image,
			},
			opacity = 0.10,
			height = image_height,
			width = image_width,
			vertical_align = vertical_align,
			horizontal_align = horizontal_align,
			---@diagnostic disable-next-line: undefined-global
			hsb = dimmer,
			repeat_x = "NoRepeat",
			repeat_y = "NoRepeat",
		},
	}
	window:set_config_overrides(overrides)
end

-- END PRIVATE FUNCTIONS }}}

-- EXPORTED MEMBERS {{{

-- Changes background image based on passed in configuration.
-- If `loop_on_startup` is true, this will create an event handler during [gui-startup](https://wezfurlong.org/wezterm/config/lua/gui-events/gui-startup.html).
-- If `change_tab_colors` is true, this will change `tab_bar` colors based off of the current image.
---@param opts BagmanSetupOptions
function M.setup(opts)
	if (not opts.dirs or #opts.dirs == 0) and (not opts.images or #opts.images == 0) then
		wezterm.log_error("BAGMAN ERROR: No directories and images provided for background images. args: ", opts)
	end
	-- clean dirs option
	opts.dirs = opts.dirs or {}
	local clean_dirs = {} ---@type table<number, BagmanCleanDir>
	for i = 1, #opts.dirs do
		local dirty_dir = opts.dirs[i]
		if type(dirty_dir) == "nil" then
			-- continue
		elseif type(dirty_dir) == "string" then
			clean_dirs[i] = {
				path = dirty_dir,
				vertical_align = default.vertical_align,
				horizontal_align = default.horizontal_align,
				object_fit = default.object_fit,
			}
		else
			clean_dirs[i] = {
				path = dirty_dir.path,
				vertical_align = dirty_dir.vertical_align or default.vertical_align,
				horizontal_align = dirty_dir.horizontal_align or default.horizontal_align,
				object_fit = dirty_dir.object_fit or default.object_fit,
			}
		end
	end
	-- clean images option
	opts.images = opts.images or {}
	local clean_images = {} ---@type table<number, BagmanCleanImage>
	for i = 1, #opts.images do
		local dirty_image = opts.images[i]
		if type(dirty_image) == "nil" then
			-- continue
		elseif type(dirty_image) == "string" then
			clean_images[i] = {
				path = dirty_image,
				vertical_align = default.vertical_align,
				horizontal_align = default.horizontal_align,
				object_fit = default.object_fit,
			}
		else
			clean_images[i] = {
				path = dirty_image.path,
				vertical_align = dirty_image.vertical_align or default.vertical_align,
				horizontal_align = dirty_image.horizontal_align or default.horizontal_align,
				object_fit = dirty_image.object_fit or default.object_fit,
			}
		end
	end
	-- setup config data with cleaned data
	bagman_data.config = {
		dirs = clean_dirs,
		images = clean_images,
		interval = opts.interval or default.interval,
		backdrop = opts.backdrop or default.backdrop,
		change_tab_colors = opts.change_tab_colors or default.change_tab_colors,
	}
	if opts.loop_on_startup then
		bagman_data.state.is_looping = true
		wezterm.on("gui-startup", function(cmd)
			local _, _, window = wezterm.mux.spawn_window(cmd or {})
			loop_forever(window:gui_window())
		end)
	else
		bagman_data.state.is_looping = false
	end
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
	if bagman_data.state.is_looping then
		wezterm.log_error("BAGMAN ERROR: only one bagman loop may exist.")
		return
	end
	bagman_data.state.is_looping = true
	loop_forever(window)
end)

wezterm.on("bagman.stop-loop", function()
	if not bagman_data.state.is_looping then
		wezterm.log_error("BAGMAN ERROR: no loop is currently running.")
		return
	end
	bagman_data.state.is_looping = false
	wezterm.log_info("BAGMAN INFO: stopped signal recieved.")
end)

---Sets a random image as the background image
---@param window Window used to change the background image
wezterm.on("bagman.next-image", function(window)
	if bagman_data.state.retries > 5 then
		wezterm.log_error("BAGMAN ERROR: Too many next-image retries. Exiting...")
		return
	end

	local image, vertical_align, horizontal_align, object_fit, ok =
		random_image_from_dirs(bagman_data.config.dirs, bagman_data.config.images)
	if not ok then
		bagman_data.state.retries = bagman_data.state.retries + 1
		return M.emit.next_image(window)
	end

	local window_dims = window:get_dimensions()
	---@diagnostic disable-next-line: redefined-local
	local scaled_width, scaled_height, ok =
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

	set_bg_image(window, image, scaled_width, scaled_height, vertical_align, horizontal_align, colors)
	bagman_data.state.retries = 0
end)

---Sets a specific image as the background image with options to scale and position it
---@param window Window used to change the background image
---@param image string path to image file
---@param opts? BagmanSetImageOptions options to scale and position image
wezterm.on("bagman.set-image", function(window, image, opts)
	opts = opts or {}
	opts.vertical_align = opts.vertical_align or default.vertical_align
	opts.horizontal_align = opts.horizontal_align or default.horizontal_align
	opts.object_fit = opts.object_fit or default.object_fit

	if not opts.width or not opts.height then
		local image_width, image_height, err = image_size.size(image)
		if err then
			wezterm.log_info(err)
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

	set_bg_image(window, image, opts.width, opts.height, opts.vertical_align, opts.horizontal_align, colors)
	bagman_data.state.retries = 0
end)

---Recomputes the background image dimensions when resized
---@param window Window used to change the background image
wezterm.on("window-resized", function(window)
	local overrides = window:get_config_overrides() or {}
	local window_dims = window:get_dimensions()
	local new_width, new_height = image_handler.contain_dimensions(
		overrides.background[2].width, ---@diagnostic disable-line: undefined-field
		overrides.background[2].height, ---@diagnostic disable-line: undefined-field
		window_dims.pixel_width,
		window_dims.pixel_height
	)
	overrides.background[2].width = new_width
	overrides.background[2].height = new_height
	window:set_config_overrides(overrides)
end)

-- END EVENT HANDLERS }}}

return M
