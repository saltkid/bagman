---@meta

---Config from user passed to setup()
---@class BagmanSetupOptions
---@field dirs table<number, BagmanDirtyDir | string> list of directories that contain images
---@field interval? number interval in seconds for changing the background
---@field backdrop? HexColor | AnsiColor bottom layer color to tint the image on top of it
---@field loop_on_startup? boolean whether to immediately start changing background every interval
---seconds on startup
---@field change_tab_colors? boolean whether to change tab bar colors based on the current background
---image

---A [BagmanSetupOptions] with optional values filled in with defaults.
---Holds the local config needed to determine how to change the background
---@class BagmanConfig
---@field dirs table<number, BagmanCleanDir | string>
---@field interval number
---@field backdrop HexColor | AnsiColor
---@field change_tab_colors boolean whether to change tab bar colors based on the current background

---a directory object in directories passed in setup()
---@class BagmanDirtyDir
---@field path string
---@field vertical_align? "Top" | "Middle" | "Bottom"
---@field horizontal_align? "Left" | "Center" | "Right"

---An [BagmanDirtyDir] cleaned by setup()
---@class BagmanCleanDir config with assigned defaults
---@field path string
---@field vertical_align "Top" | "Middle" | "Bottom"
---@field horizontal_align "Left" | "Center" | "Right"

---Holds the local config and state of BGChanger
---@class BagmanData
---@field config BagmanConfig
---@field state BagmanState

---Holds the local state needed to determine whether to stop because of error
---or because of user input, keep looping, etc.
---@class BagmanState
---@field is_looping boolean
---@field retries number
