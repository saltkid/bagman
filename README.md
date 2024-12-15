# bagman
Background Manager for [Wezterm](https://github.com/wez/wezterm/) that automatically cycles through
different backgrounds at a user set interval. It can change `tab_bar` colors based on the
background image. bagman also simulates css's
[`object-fit: contain`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit#contain), even
when the window gets resized.

Updating the background image happens at the foreground. Usually, the interrupts are quick but the it
might get too long if the image is too large.

# Installation
## Prerequisites
1. install [ImageMagick](https://imagemagick.org/)
    - this is to get the [`identify`](https://imagemagick.org/script/identify.php) command for
    getting image dimensions to simulate css's
    [`object-fit: contain`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit#contain)
    since Wezterm's
    [`height = "Contain"`](https://wezfurlong.org/wezterm/config/lua/config/background.html?h=Contain#layer-definition)
    does not respect aspect ratio. See [this issue](https://github.com/wez/wezterm/issues/3708) for
    more info

## Plugin installation
To conform with wezterm's current
[plugin system](https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd),
install bagman via:
```lua
local wezterm = require("wezterm")
local bagman = wezterm.plugin.require("https://github.com/saltkid/bagman")
local config = wezterm.config_builder()
bagman.apply_to_config(config)
--[[ the rest of your config
    ...
]]--
return config
```
bagman only adds event listeners so `bagman.apply_to_config(config)` does nothing. bagman does have
a `setup()` function though.

# Sample Setup
```lua
bagman.setup({
    -- required
    -- pass in directories that contain images for bagman to search in
    directories = {
        -- you can pass in directories as a string (must be absolute path),
        "/abs/path/to/dir",

        -- or you can pass it in as a table where you can define a custom horizontal_align and/or
        -- vertical_align for images under that directory.
        {
            path = os.getenv("HOME") .. "/path/to/home/subdir",
            vertical_align = "Top", -- default: "Middle"
            horizontal_align = "Right", -- default: "Center"
        },

        -- horizontal_align and vertical_align are optional.
        -- this is equivalent to just passing it in as a string.
        {
            path = os.getenv("HOME") .. "/path/to/another/home/subdir",
        },
    },

    -- in seconds.
    -- default: 30 * 60
    interval = 10 * 60,

    -- can be any ansi color like "Maroon", "Green", or "Aqua"
    -- or any hex color string like "#121212"
    -- default: "#000000"
    backdrop = "#161616",

    -- whether to immediately start changing bg image every <interval> seconds on
    -- startup.
    -- default: false
    start_looping = true,

    -- whether to change tab_bar colors based off the current background image
    -- default: false
    change_tab_colors = true,
})
```

# actions and emitters
## Overview
bagman has a soft wrapper around  `wezterm.action.EmitEvent` and `wezterm.emit` to more easily
interact with bagman event listeners.

## Examples
For example, you can manually change the background image through a keybind
```lua
local wezterm = require("wezterm")
local bagman = wezterm.plugin.require("https://github.com/saltkid/bagman")

return {
    keys = {
        {
            mods = 'CTRL|ALT|SHIFT',
            key = 'i',
            -- alias for wezterm.action.EmitEvent("bagman.next-image")
            action = bagman.action.next_image,
        },
    },
}
```

You can also manually emit a next image event with a [Window object](https://wezfurlong.org/wezterm/config/lua/window/).
This example is to change the bg image when a `bell` event occurs.
```lua
local wezterm = require("wezterm")
local bagman = wezterm.plugin.require("https://github.com/saltkid/bagman")

wezterm.on("bell", function(window, pane)
    -- alias for wezterm.emit("bagman.next-image", window)
    bagman.emit.next_image(window)
    --[[ your other code
        ...
    ]]--
end)
```

## List of actions
Usage: `bagman.action.action_name`

Alias for event format: `wezterm.action.EmitEvent("bagman.action-name")`
| action_name | alias for event | description |
| ----------- | --------- | ----------- |
| `next_image`  | `"bagman.next-image"` | changes the bg image |
| `start_loop`  | `"bagman.start-loop"` | starts the auto cycle bg images loop at every user set interval (default: 30) |
| `stop_loop`  | `"bagman.stop-loop"` | stops the current auto cycle bg images loop |

## List of emitters
Usage: `bagman.emit.emitter_name(win)` where `win` is a
[Window object](https://wezfurlong.org/wezterm/config/lua/window/).

Alias for event format: `wezterm.emit("bagman.emitter-name", win)`
| action_name | alias for event | description |
| ----------- | --------- | ----------- |
| `next_image`  | `"bagman.next-image"` | changes the bg image |
| `start_loop`  | `"bagman.start-loop"` | starts the auto cycle bg images loop at every user set interval (default: 30) |
| `stop_loop`  | `"bagman.stop-loop"` | stops the current auto cycle bg images loop |
