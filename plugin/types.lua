---@meta

-- ALIASES {{{

---@alias VerticalAlign "Top" | "Middle" | "Bottom"
---@alias HorizontalAlign "Left" | "Center" | "Right"
---@alias ObjectFit "Contain" | "Cover" | "Fill" | "None" | "ScaleDown"
---@alias Hsb { hue: f32, saturation: f32, brightness: f32 }
---@alias Backdrop  { color: HexColor | AnsiColor, opacity: f32 }

-- }}}

-- IMAGE METADATA {{{

---@class ImageDimensions
---@field width number | string | ObjectFit
---@field height number | string | ObjectFit

-- }}}

-- BAGMAN API {{{

---Config from user passed to setup()
---@class BagmanSetupOptions
-- whether to immediately start changing background every interval
-- seconds on startup
---@field auto_cycle? boolean
---@field backdrop? Backdrop | HexColor | AnsiColor
-- list of directories that contain images
---@field dirs table<number, BagmanDirtyDir | string>
-- whether to change tab bar colors based on the current background
-- image
---@field change_tab_colors? boolean
---@field experimental BagmanExperimental
-- list of image files
---@field images table<number, BagmanDirtyImage | string> interval in seconds for changing the background
---@field interval? number

-- experimental setup option. be warned when using as these might change at any
-- time
---@class BagmanExperimental
-- whether the wezterm you are using is built using my branch at
-- https://github.com/saltkid/wezterm/tree/fix/contain-tall-images
---@field contain_fix_wezterm_build bool

-- args passed to bagman.emit.set_image(window, path/to/image, { ... })
---@class BagmanSetImageOptions
---@field height? number
---@field horizontal_align? HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb? Hsb
---@field object_fit? ObjectFit
-- from 0.0 above
---@field opacity? f32
---@field vertical_align? VerticalAlign
---@field width? number

-- }}}

-- BAGMAN LOCAL STATE {{{

---Holds the local config and state of BGChanger
---@class BagmanData
---@field config BagmanConfig
---@field state BagmanState

-- These are the possible fields in wezterm.GLOBAL.bagman
-- Since these are used for bagman functionality, please don't arbitrarily
-- change these.
---@class BagmanWeztermGlobal
-- stores the latest image set by bagman. Used for knowing what object_fit an
-- image has when resizing. Also used for determining whether an image cycle
-- has already started on startup.
---@field current_image BagmanCurrentImage
-- user triggered `stop_loop()` (false) and `start_loop()` (true)
---@field manually_cycle boolean

-- A [BagmanSetupOptions] with optional values filled in with defaults.
-- Holds the local config needed to determine how to change the background.
-- should be READONLY and never changed after initial setup.
---@class BagmanConfig
---@field backdrop Backdrop
-- whether to change tab bar colors based on the current background
---@field change_tab_colors boolean
---@field dirs table<number, BagmanCleanDir>
---@field __experimental BagmanExperimental
---@field images table<number, BagmanCleanImage>
---@field interval number

-- Holds the local state needed to determine whether to stop because of error
-- or because of user input, keep looping, etc. MUTABLE
---@class BagmanState
---@field auto_cycle boolean
---@field retries number

-- }}}

-- BAGMAN DIRECTORY AND IMAGE OBJECTS FROM SETUP {{{

-- a directory object in directories passed in setup()
---@class BagmanDirtyDir
---@field horizontal_align? HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb? Hsb
---@field object_fit? ObjectFit
-- from 0.0 to 1.0
---@field opacity? f32
---@field path string
---@field vertical_align? VerticalAlign

-- An [BagmanDirtyDir] cleaned by setup()
-- config with assigned defaults
---@class BagmanCleanDir
---@field horizontal_align HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb Hsb
---@field object_fit ObjectFit
-- from 0.0 above
---@field opacity f32
---@field path string
---@field vertical_align VerticalAlign

-- an image file object in images passed in setup()
---@class BagmanDirtyImage
---@field horizontal_align? HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb? Hsb
---@field object_fit? ObjectFit
-- from 0.0 to 1.0
---@field opacity? f32
---@field path string
---@field vertical_align? VerticalAlign

---An [BagmanDirtyImage] cleaned by setup()
---@class BagmanCleanImage config with assigned defaults
---@field horizontal_align HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb Hsb
---@field object_fit ObjectFit
-- from 0.0 above
---@field opacity f32
---@field path string
---@field vertical_align VerticalAlign

-- }}}

-- BAGMAN CURRENT IMAGE OBJECT {{{

-- current background image set by bagman. Only really used when resizing window since I
-- need to know what object fit an image has.
---@class BagmanCurrentImage
---@field height number | string | ObjectFit scaled width. can be in px, "n%", or any of the ObjectFit values
---@field horizontal_align HorizontalAlign
-- valid values for its fields are from 0.0 to above
---@field hsb Hsb
---@field object_fit ObjectFit
-- from 0.0 above
---@field opacity f32
---@field path string
---@field vertical_align VerticalAlign
---@field width number | string | ObjectFit scaled width. can be in px, "n%", or any of the ObjectFit values

-- }}}
