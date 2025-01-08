---@meta

-- ALIASES {{{

---@alias VerticalAlign "Top" | "Middle" | "Bottom"
---@alias HorizontalAlign "Left" | "Center" | "Right"
---@alias ObjectFit "Contain" | "Cover" | "Fill" | "None" | "ScaleDown"
---@alias Hsb { hue: f32, saturation: f32, brightness: f32 }
-- }}}

---Config from user passed to setup()
---@class BagmanSetupOptions
---@field auto_cycle? boolean whether to immediately start changing background every interval
---seconds on startup
---@field backdrop? HexColor | AnsiColor bottom layer color to tint the image on top of it
---@field dirs table<number, BagmanDirtyDir | string> list of directories that contain images
---@field change_tab_colors? boolean whether to change tab bar colors based on the current background
---image
---@field images table<number, BagmanDirtyImage | string> list of image files
---@field interval? number interval in seconds for changing the background

---A [BagmanSetupOptions] with optional values filled in with defaults.
---Holds the local config needed to determine how to change the background
---@class BagmanConfig
---@field backdrop HexColor | AnsiColor
---@field change_tab_colors boolean whether to change tab bar colors based on the current background
---@field dirs table<number, BagmanCleanDir>
---@field images table<number, BagmanCleanImage>
---@field interval number

---a directory object in directories passed in setup()
---@class BagmanDirtyDir
---@field horizontal_align? HorizontalAlign
---@field hsb? Hsb valid values for its fields are from 0.0 to above
---@field object_fit? ObjectFit
---@field opacity? f32 from 0.0 to 1.0
---@field path string
---@field scale? f32
---@field vertical_align? VerticalAlign

---An [BagmanDirtyDir] cleaned by setup()
---@class BagmanCleanDir config with assigned defaults
---@field horizontal_align HorizontalAlign
---@field hsb Hsb valid values for its fields are from 0.0 to above
---@field object_fit ObjectFit
---@field opacity f32 from 0.0 to 1.0
---@field path string
---@field scale f32
---@field vertical_align VerticalAlign

---an image file object in images passed in setup()
---@class BagmanDirtyImage
---@field horizontal_align? HorizontalAlign
---@field hsb? Hsb valid values for its fields are from 0.0 to above
---@field object_fit? ObjectFit
---@field opacity? f32 from 0.0 to 1.0
---@field path string
---@field scale? f32
---@field vertical_align? VerticalAlign

---An [BagmanDirtyImage] cleaned by setup()
---@class BagmanCleanImage config with assigned defaults
---@field horizontal_align HorizontalAlign
---@field hsb Hsb valid values for its fields are from 0.0 to above
---@field object_fit ObjectFit
---@field opacity f32 from 0.0 to 1.0
---@field path string
---@field scale f32
---@field vertical_align VerticalAlign

---Holds the local config and state of BGChanger
---@class BagmanData
---@field config BagmanConfig
---@field state BagmanState

---Holds the local state needed to determine whether to stop because of error
---or because of user input, keep looping, etc.
---@class BagmanState
---@field auto_cycle boolean
---@field current_image BagmanCurrentImage
---@field retries number

---@class BagmanCurrentImage
---@field height number
---@field horizontal_align HorizontalAlign
---@field hsb Hsb valid values for its fields are from 0.0 to above
---@field object_fit ObjectFit
---@field opacity f32 from 0.0 to 1.0
---@field path string
---@field scale f32
---@field vertical_align VerticalAlign
---@field width number

---@class BagmanSetImageOptions
---@field height number
---@field horizontal_align HorizontalAlign
---@field hsb Hsb valid values for its fields are from 0.0 to above
---@field object_fit ObjectFit
---@field opacity f32 from 0.0 to 1.0
---@field scale f32
---@field vertical_align VerticalAlign
---@field width number
