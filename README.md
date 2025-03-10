# bagman
Background Manager for [Wezterm](https://github.com/wez/wezterm/) that
automatically cycles through different backgrounds at a user-defined interval.
It handles configuring the `background` config option and will overwrite any
previous values. Usually, the interrupts to change background are quick but it
might get too long if the image is too large.

## Key Features
- auto cycle background images at a user-defined interval.
- set different
[`object-fit`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit)
strategies for background images
- optional changing of `tab_bar` colors based on the current background image

## Demo
*note: changing tab bar colors based on the background image is enabled*

### change image every 3 seconds
https://github.com/user-attachments/assets/2ef8d21e-b209-4845-8904-d946235540db

see [setup options](#bagman-setup-options) for more info

### manually changing image through a keybind
https://github.com/user-attachments/assets/3220e507-dbc4-48af-9331-af6be870fbee

see [`action.next_image`](#bagmanactionnext_image) for more info

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
        "/path/to/dir-1",
        {
            path = wezterm.home_dir .. "/path/to/dir-2",
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
- [`current_image()`](#bagmancurrent_image)
- [`action.next_image`](#bagmanactionnext_image)
- [`action.start_loop`](#bagmanactionstart_loop)
- [`action.stop_loop`](#bagmanactionstop_loop)
- [`emit.next_image(window)`](#bagmanemitnext_imagewindow)
- [`emit.set_image(window, image, opts)`](#bagmanemitset_imagewindow-image-opts)
- [`emit.start_loop(window)`](#bagmanemitstart_loopwindow)
- [`emit.stop_loop(window)`](#bagmanemitstop_loopwindow)

### `bagman.apply_to_config(config)`
bagman only registers event listeners so `bagman.apply_to_config(config)` does
nothing for now.
### `bagman.setup(opts)`
Here is a sample setup with all options:
```lua
bagman.setup({
    dirs = {
        "/abs/path/to/dir", -- can define as a string
        { -- or as a table with options
            path = wezterm.home_dir .. "/path/to/home/subdir", -- no default, required
            vertical_align = "Top", -- default: Center
            horizontal_align = "Right", -- default: Middle
            opacity = 0.1, -- default: 1.0
            hsb = { 
                hue = 1.0, -- default: 1.0
                saturation = 1.0, -- default: 1.0
                brightness = 1.0, -- default: 1.0
            }, 
            object_fit = "Fill", -- default: "Contain"
        },
        -- more dirs...
    },
    images = {
        {
            path = "/abs/path/to/image", -- no default, required
            vertical_align = "Bottom", -- default: Center
            object_fit = "ScaleDown", -- default: Center
        },
        wezterm.home_dir .. "/path/to/another/image.jpg",
        -- more images...
    },
    interval = 10 * 60, -- default: 30 * 60
    backdrop = "#161616", -- equivalent to { color = "#161616", opacity = 1.0 }
    auto_cycle = true, -- default: true
    change_tab_colors = true, -- default: false
})
```
All setup options are, well, optional. The only two requirement are:
1. pass in at least one `dirs` or `images` entry.
2. if a `dirs` or `image` entry is a table instead of a string, it must define
a `path`
#### bagman setup options
1. `dirs`
- Directories which contain images that bagman chooses from when changing
the background image. It can be passed in as a string or as a table with
options defined for that specific path.
- The options for each entry are:
    - `horizontal_align`
        - valid values: `"Left"`, `"Center"`, `"Right"`
        - default: `"Center"`
        - behaves the same as wezterm's
    - `hsb`
        - fields: `hue`, `saturation`, `brightness`
        - valid values for fields: from `0.0` above
        - default values for all fields: `1.0`
        - behaves the same as wezterm's
    - `object_fit`
        - how the image should be resized to fit the window
        - valid values: `"Contain"`, `"Cover"`, `"Fill"`, `"None"`, `"ScaleDown"`
        - default: `"Contain"`
        - behave the same as css's
        [`object-fit`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit)
    - `opacity` 
        - valid values: from `0.0` to `1.0`
        - default: `1.0`
        - behaves the same as wezterm's
    - `path`
        - absolute path to a directory
        - no default, required
    - `vertical_align`
        - valid values: `"Top"`, `"Middle"`, `"Bottom"`
        - default: `"Middle"`
        - behaves the same as wezterm's
2. `images`
- Images that bagman chooses from when changing the background image.
- Its options are the same as a `dirs` entry's but `path` referes to a path
to an image file instead.
3. `auto_cycle`
- Whether to immediately start changing bg image every <interval> seconds on
startup.
- default: `true`
4. `backdrop`
- The color layer below the image. It can be any ansi color like `"Maroon"`,
`"Green"`, or `"Aqua"`, or any hex color string like `"#121212"`.
- It can also
be a table specifying the color as ansi or hex string, and the opacity as a
number from 0.0 to 1.0
- default: `{ color = "#000000", opacity = 1.0 }`
5. `change_tab_colors`
- Whether to change tab_bar colors based off the current background image
- default: `false`
6. `interval`
- Interval in seconds on when to trigger a background image change.
- default: `30 * 60`

### `bagman.current_image()`
Returns the latest background image set by bagman, along with its options. Note
that this is readonly and even if the return value's fields are reassigned, it
will not affect any bagman functionality.

The returned current image object's fields are the same as the options of a
`dirs` or `images` entry in [`bagman.setup()`](#bagman-setup-options), with two
additional fields:
1. `height` of the image in px
2. `width` of the image in px
### `bagman.action.next_image`
_Alias for: `wezterm.action.EmitEvent("bagman.next-image")`_

Changes the background image to a random image based on setup options. Random
images are chosen from the `images` setup option, and images in a random dir in
`dirs` setup option


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
### `bagman.action.start_loop`
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

### `bagman.action.stop_loop`
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
| `height` | `nil` |
| `horizontal_align` | `"Center"` |
| `hsb` | `{ hue = 1.0, saturation = 1.0, brightness = 1.0 }` |
| `object_fit` | `"Contain"` |
| `opacity` | `1.0` |
| `vertical_align` | `"Middle"` |
| `width` | `nil` |

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
