local wezterm = require("wezterm") --[[@as Wezterm]]
local image_size = require("bagman.image-size") --[[@as ImageSize]]

---@class ImageResizer
local M = {}

-- Returns the resized dimensions of an image based on the specified object_fit
---@param image string path to image file
---@param window_width number
---@param window_height number
---@param object_fit ObjectFit
---@param __experimental_contain_fix_wezterm_build boolean whether the wezterm
-- you are using is built using the contain fix pr I did
-- [here](https://github.com/wez/wezterm/pull/6554)
---@return { original: ImageDimensions, scaled: ImageDimensions }? dims original and scaled image dimensions
function M.resize(
    image,
    window_width,
    window_height,
    object_fit,
    __experimental_contain_fix_wezterm_build
)
    if __experimental_contain_fix_wezterm_build then
        return M.resize_v2(image, window_width, window_height, object_fit)
    end

    local image_dims = image_size.size(image)
    if image_dims.err then
        wezterm.log_error("BAGMAN IMAGE HANDLER ERROR:", image_dims.err)
        return nil
    end

    ---@type ImageDimensions
    local scaled_dims
    if "Contain" == object_fit then
        scaled_dims = M.contain_dimensions(
            image_dims.width,
            image_dims.height,
            window_width,
            window_height
        )
    elseif "Cover" == object_fit then
        scaled_dims = M.cover_dimensions(
            image_dims.width,
            image_dims.height,
            window_width,
            window_height
        )
    elseif "Fill" == object_fit then
        scaled_dims = { width = window_width, height = window_height }
    elseif "None" == object_fit then
        scaled_dims = image_dims
    elseif "ScaleDown" == object_fit then
        if
            image_dims.width > window_width
            or image_dims.height > window_height
        then
            scaled_dims = M.contain_dimensions(
                image_dims.width,
                image_dims.height,
                window_width,
                window_height
            )
        else
            scaled_dims = image_dims
        end
    else
        wezterm.log_error(
            "BAGMAN IMAGE HANDLER ERROR: unknown object_fit:",
            object_fit
        )
    end

    return { original = image_dims, scaled = scaled_dims }
end

-- WARN: EXPERIMENTAL
-- Returns the resized dimensions of an image based on the specified object_fit
-- Skip computation for "Contain", "Cover", and "Fill"
---@param image string path to image file
---@param window_width number
---@param window_height number
---@param object_fit ObjectFit
---@return { original: ImageDimensions, scaled: ImageDimensions }? dims
-- original and scaled image dimensions
function M.resize_v2(image, window_width, window_height, object_fit)
    if "Contain" == object_fit or "Cover" == object_fit then
        local dims = { width = object_fit, height = object_fit }
        return { original = dims, scaled = dims }
    elseif "Fill" == object_fit then
        local dims = { width = "100%", height = "100%" }
        return { original = dims, scaled = dims }
    elseif "None" == object_fit then
        local image_dims = image_size.size(image)
        if image_dims.err then
            wezterm.log_error("BAGMAN IMAGE HANDLER ERROR:", image_dims.err)
            return nil
        end
        return { original = image_dims, scaled = image_dims }
    elseif "ScaleDown" == object_fit then
        local image_dims = image_size.size(image)
        if image_dims.err then
            wezterm.log_error("BAGMAN IMAGE HANDLER ERROR:", image_dims.err)
            return nil
        end
        local scaled_dims
        if
            image_dims.width > window_width
            or image_dims.height > window_height
        then
            scaled_dims = M.contain_dimensions(
                image_dims.width,
                image_dims.height,
                window_width,
                window_height
            )
        else
            scaled_dims = image_dims
        end
        return { original = image_dims, scaled = scaled_dims }
    else
        wezterm.log_error(
            "BAGMAN IMAGE HANDLER ERROR: unknown object_fit:",
            object_fit
        )
        return nil
    end
end

---Computes css's `object-fit: contain` width and height px of an image using
---current window width and height as basis.
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@return ImageDimensions dims
function M.contain_dimensions(
    image_width,
    image_height,
    window_width,
    window_height
)
    local scale_width = window_width / image_width
    local scale_height = window_height / image_height
    local scale = math.min(scale_width, scale_height)
    return {
        width = math.floor(image_width * scale),
        height = math.floor(image_height * scale),
    }
end

---Computes css's `object-fit: cover` width and height px of an image using
---current window width and height as basis.
---@param image_width number
---@param image_height number
---@param window_width number
---@param window_height number
---@return ImageDimensions dims
function M.cover_dimensions(
    image_width,
    image_height,
    window_width,
    window_height
)
    local scale_width = window_width / image_width
    local scale_height = window_height / image_height
    local scale = math.max(scale_width, scale_height)
    return {
        width = math.floor(image_width * scale),
        height = math.floor(image_height * scale),
    }
end

return M
