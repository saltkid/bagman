---@meta

---Config from user passed to setup()
---@class BagmanSetupOptions
---@field dirs table<number, BagmanDirtyDir | string> list of directories that contain images
---@field images table<number, BagmanDirtyImage | string> list of image files
---@field interval? number interval in seconds for changing the background
---@field backdrop? HexColor | AnsiColor bottom layer color to tint the image on top of it
---@field auto_cycle? boolean whether to immediately start changing background every interval
---seconds on startup
---@field change_tab_colors? boolean whether to change tab bar colors based on the current background
---image

---A [BagmanSetupOptions] with optional values filled in with defaults.
---Holds the local config needed to determine how to change the background
---@class BagmanConfig
---@field dirs table<number, BagmanCleanDir>
---@field images table<number, BagmanCleanImage>
---@field interval number
---@field backdrop HexColor | AnsiColor
---@field change_tab_colors boolean whether to change tab bar colors based on the current background

-- GENERAL OPTIONS {{{

---@alias vertical_align_opts "Top" | "Middle" | "Bottom"
---@alias horizontal_align_opts "Left" | "Center" | "Right"
---@alias object_fit_opts "Contain" | "Cover" | "Fill" | "None" | "ScaleDown"

-- }}}

---a directory object in directories passed in setup()
---@class BagmanDirtyDir
---@field path string
---@field vertical_align? vertical_align_opts
---@field horizontal_align? horizontal_align_opts
---@field object_fit? object_fit_opts

---An [BagmanDirtyDir] cleaned by setup()
---@class BagmanCleanDir config with assigned defaults
---@field path string
---@field vertical_align vertical_align_opts
---@field horizontal_align horizontal_align_opts
---@field object_fit object_fit_opts

---an image file object in images passed in setup()
---@class BagmanDirtyImage
---@field path string
---@field vertical_align? vertical_align_opts
---@field horizontal_align? horizontal_align_opts
---@field object_fit? object_fit_opts

---An [BagmanDirtyImage] cleaned by setup()
---@class BagmanCleanImage config with assigned defaults
---@field path string
---@field vertical_align vertical_align_opts
---@field horizontal_align horizontal_align_opts
---@field object_fit object_fit_opts

---Holds the local config and state of BGChanger
---@class BagmanData
---@field config BagmanConfig
---@field state BagmanState

---Holds the local state needed to determine whether to stop because of error
---or because of user input, keep looping, etc.
---@class BagmanState
---@field is_looping boolean
---@field retries number
---@field current_image BagmanCurrentImage

---@class BagmanCurrentImage
---@field path string
---@field vertical_align vertical_align_opts
---@field horizontal_align horizontal_align_opts
---@field object_fit object_fit_opts
---@field width number
---@field height number

---@class BagmanSetImageOptions
---@field vertical_align? vertical_align_opts
---@field horizontal_align? horizontal_align_opts
---@field object_fit? object_fit_opts
---@field width? number
---@field height? number
