# bagman
Background Manager for [Wezterm](https://github.com/wez/wezterm/) that
automatically cycles through different backgrounds at a user-defined interval.
Usually, the interrupts to change background are quick but it might get too long
if the image is too large.

## Key Features
- auto cycle background images at a user-defined interval.
- set different
[`object-fit`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit)
strategies for background images
- optional changing of `tab_bar` colors based on the current background image

# Installation
To conform with wezterm's current
[plugin system](https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd),
install bagman via:
```lua
local wezterm = require("wezterm")
local bagman = wezterm.plugin.require("https://github.com/saltkid/bagman")
local config = wezterm.config_builder()

bagman.setup({
    dirs = {
        "/abs/path/to/dir",
        {
            path = os.getenv("HOME") .. "/path/to/home/subdir",
            object_fit = "Contain",
            horizontal_align = "Right",
        },
    },
    interval = 10 * 60,
    change_tab_colors = true,
})
bagman.apply_to_config(config)

return config
```

---

# bagman API Reference
## Table of Contents
- [`apply_to_config(config)`](#bagmanapply_to_configconfig)
- [`setup(opts)`](#bagmansetupopts)
- [`action.next_image()`](#bagmanactionnext_image)
- [`action.start_loop()`](#bagmanactionstart_loop)
- [`action.stop_loop()`](#bagmanactionstop_loop)
- [`emit.next_image(window)`](#bagmanemitnext_imagewindow)
- [`emit.set_image(window, image, opts)`](#bagmanemitset_imagewindow-image-opts)
- [`emit.start_loop(window)`](#bagmanemitstart_loopwindow)
- [`emit.stop_loop(window)`](#bagmanemitstop_loopwindow)

### `bagman.apply_to_config(config)`
bagman only registers event listeners so `bagman.apply_to_config(config)` does
nothing for now.
### `bagman.setup(opts)`
```lua
bagman.setup({
    -- pass in directories that contain images for bagman to search in
    dirs = {
        -- you can pass in directories as a string (must be absolute path),
        "/abs/path/to/dir",

        -- or you can pass it in as a table where you can define options for
        -- images under that directory.
        {
            path = os.getenv("HOME") .. "/path/to/home/subdir",
            vertical_align = "Top", -- default: "Middle"
            horizontal_align = "Right", -- default: "Center"
            opacity = 0.1, -- default: 1.0
            hsb = { 
                hue = 1.0, -- default: 1.0
                saturation = 1.0, -- default: 1.0
                brightness = 1.0, -- default: 1.0
            }, 
            object_fit = "Fill", -- default: "Contain"
            scale = 0.5, -- default: 1.0
        },

        -- all fields except path are optional.
        -- below is equivalent to just passing it in as a string.
        {
            path = os.getenv("HOME") .. "/path/to/another/home/subdir",
        },
    },
    -- you can also pass in image files
    images = {
        -- as string
        "/abs/path/to/image",

        -- as a table with some options
        {
            path = os.getenv("HOME") .. "/path/to/another/image.jpg",
            vertical_align = "Bottom", -- default: "Middle"
            object_fit = "ScaleDown", -- default: "Contain"
        },

        -- as a table without the options
        {
            path = os.getenv("HOME") .. "/path/to/another/image.gif",
        },
    },

    -- Interval in seconds on when to trigger a background image change.
    -- default: 30 * 60
    interval = 10 * 60,

    -- Color Layer below the image. Affects the overall tint of the background
    -- can be any ansi color like "Maroon", "Green", or "Aqua" or any hex color
    -- string like "#121212"
    -- default: "#000000"
    backdrop = "#161616",

    -- Whether to immediately start changing bg image every <interval> seconds
    -- on startup.
    -- default: true
    auto_cycle = true,

    -- whether to change tab_bar colors based off the current background image
    -- default: false
    change_tab_colors = true,
})
```

### `bagman.current_image()`
Returns the latest background image set by bagman, along with its options. Note
that this is readonly and even if the return value's fields are reassigned, it
will not affect any bagman functionality.

Fields:
1. `height`
    - height of the image in px
2. `horizontal_align`
    - valid values: `"Left"`, `"Center"`, `"Middle"`
    - same as wezterm's
3. `hsb`
    - fields: `hue`, `saturation`, `brightness`
    - valid values for fields: from `0.0` above
    - same as wezterm's
4. `object_fit`
    - how the image should be resized to fit the window
    - valid values: `"Contain"`, `"Cover"`, `"Fill"`, `"None"`, `"ScaleDown"`
    - these behave the same as css's
    [`object-fit`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit)
5. `opacity` 
    - valid values: from `0.0` to `1.0`
    - same as wezterm's
6. `path`
    - absolute path to image file
7. `scale`
    - scale multiplier applied to image after the scaling done by `object_fit`.
    For example, `object_fit = "Contain", scale = 0.5` will first scale the
    image to fit within the window, then scale it down to 50% of that.
    - valid values: from `0.0` above
8. `vertical_align`
    - valid values: `"Top"`, `"Middle"`, `"Bottom"`
    - same as wezterm's
9. `width`
    - width of the image in px

### `bagman.action.next_image()`
_Alias for: `wezterm.action.EmitEvent("bagman.next-image")`_

Changes the background image to a random image based on setup options. Random
images are chosen from a images in a random dir in `dirs` setup option
along with the `images` option

Example: change bg image through a keybind
```lua
config.keys = {
    {
        mods = 'CTRL',
        key = 'i',
        action = bagman.action.next_image,
        -- action = wezterm.action.EmitEvent("bagman.next-image"),
    },
},
```
### `bagman.action.start_loop()`
_Alias for: `wezterm.action.EmitEvent("bagman.start-loop")`_

Starts the auto cycle bg images loop at every user set interval. Only one loop
may be present so triggering this event again will safely do nothing. If
`auto_cycle` setup option is set to true, triggering this action will not do
anything since `auto_cycle = true` will create an image cycling loop on
startup.
```lua
bagman.setup({
    auto_cycle = true, -- will start the image cycle loop on startup
    dirs = { ... },
    ...
})
```
See [`bagman.action.next_image()`](#bagman.action.next_image()) for an example
on how to use a bagman action with a keybind.

### `bagman.action.stop_loop()`
_Alias for: `wezterm.action.EmitEvent("bagman.stop-loop")`_

Stops the current auto cycle bg images loop. Does nothing if there are no loops
currently running.

See [`bagman.action.next_image()`](#bagman.action.next_image()) for an example
on how to use a bagman action with a keybind.

### `bagman.emit.next_image(window)`
_Alias for: `wezterm.emit("bagman.next-image", window)`_

Changes the background image to a random image based on setup options. Random
images are chosen from a images in a random dir in `dirs` setup option
along with the `images` option

Example: change the bg image when you open a new tab
```lua
wezterm.on("new-tab-button-click", function(window, pane)
    bagman.emit.next_image(window)
    ...
end)
```

### `bagman.emit.set_image(window, image, opts)`
_Alias for: `wezterm.emit("bagman.set-image", window, "/path/to/image", {})`_

Sets a specified image path as the background image where you can define
options to scale and position the image however you'd like. Specifically, the
options are as follows:
| option | default value |
|--------|---------------|
| `vertical_align` | `"Middle"` |
| `horizontal_align` | `"Center"` |
| `object_fit` | `"Contain"` |
| `width` | `nil` |
| `height` | `nil` |

Note that if no width and height is given, the image will be scaled according
to the `object_fit` option. Same goes for when only either width or height is
given. Only when both `width` and `height` are given will the scaling ignore
the `object_fit` option.

Example: change background image temporarily on `"bell"` event, like a jumpscare
```lua
wezterm.on("bell", function(window, pane)
    local overrides = window:get_config_overrides() or {}

    local prev_image = bagman.current_image()
    local jumpscare = "/path/to/some/image.png"
    bagman.emit.set_image(window, jumpscare, {
        object_fit = "Fill",
    })

    -- put back the previous image after 2 seconds
    wezterm.time.call_after(2, function()
        bagman.emit.set_image(window, prev_image.path, {
            -- override the object_fit option and use previously calculated
            -- dimensions to avoid redundant processing.
            width = prev_image.width,
            height = prev_image.height,
        })
    end)
end)
```

### `bagman.emit.start_loop(window)`
_Alias for: `wezterm.emit("bagman.start-loop", window)`_

Starts the auto cycle bg images loop at every user set interval. Only one loop
may be present so manually emitting this event again will safely do nothing. If
`auto_cycle` setup option is set to true, triggering this action will not do
anything since `auto_cycle = true` will create an image cycling loop on
startup.
```lua
bagman.setup({
    auto_cycle = true, -- will start the image cycle loop on startup
    dirs = { ... },
    ...
})
```

### `bagman.emit.stop_loop(window)`
_Alias for: `wezterm.emit("bagman.stop-loop", window)`_

Stops the current auto cycle bg images loop. Does nothing if there are no loops
currently running.
