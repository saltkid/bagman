-- just contains the initial parser to identify which parser to use on a file
local Public = {}

-- Contains the image file parsers.
--
-- Constraints:
-- * ALL parsers have their magic numbers checked beforehand by
--   `Public.image_size()` but the file offset is reset at 0.
-- * ALL parsers have handle to files that are at least 8 bytes in length so
--   you can optimize around that.
-- * ALL readers SHOULD NOT close the file handle passed to it.
--   `Public.image_size` will handle that
local private = {}

-- PUBLIC MEMBERS {{{
-- Interface for getting file size of different file types. Supported types:
-- * PNG
-- * JPEG
-- * GIF
-- * BMP
-- * ICO
-- * TIFF
-- * PNM
-- * DDS
-- * TGA
-- * farbfeld
---@param file_path string path to image file
---@return number width
---@return number height
---@return string? err error message if errored
function Public.image_size(file_path)
	local handle, err = io.open(file_path, "rb")
	if not handle then
		return 0, 0, string.format("Unable to open file '%q': %q", file_path, err)
	end

	local magic = handle:read(8)
	if not magic or #magic < 8 then
		return 0, 0, "Failed to read file"
	end
	handle:seek("set", 0)

	local width, height
	if magic:sub(1, 4) == "\137PNG" then
		width, height, err = private.png_size(handle)
	elseif magic:sub(1, 2) == "\xFF\xD8" then
		width, height, err = private.jpeg_size(handle)
	elseif magic:sub(1, 3) == "GIF" then
		width, height, err = private.gif_size(handle)
	end

	handle:close()
	return width, height, err
end
-- }}}

-- PRIVATE MEMBERS {{{

-- get width and height of a png file.
-- Details:
-- BYTE ORDER: big endian
--
-- DATA:
-- * 8: "89 50 4E 47 0D 0A 1A 0A" or "\137PNG\r\n\26\n"
-- * 16: IHDR chunk
--   * 4: IHDR chunk length
--   * 4: "IHDR" (chunk type)
--   * 4: width
--   * 4: height
--
-- total needed: 24
-- width offset: 17
-- height offset: 21
--
-- references:
-- - https://www.w3.org/TR/png-3/
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.png_size(handle)
	local data = handle:read(24)
	if #data < 24 then
		return 0, 0, string.format("Invalid PNG file: malformed header (too short) (%q)", data)
	end
	local width = string.unpack(">I4", data:sub(17, 20))
	local height = string.unpack(">I4", data:sub(21, 24))
	return width, height, nil
end

-- get width and height of a jpeg file
-- Details:
-- BYTE ORDER: big endian
--
-- DATA:
-- * 2: "\xFF\xD8"
-- * n: chunks
--   * 1: "\xFF" (marker)
--   * 1: "\xC0" or "\xC2" (chunk type)
--   * 2: chunk length
--   * 1: bits per channel
--   * 2: width
--   * 2: height
--
-- total needed: variable
-- total chunk size needed: 9
-- width offset from chunk marker: 6
-- height offset from chunk marker: 8
--
-- references:
-- - https://stackoverflow.com/questions/2517854/getting-image-size-of-jpeg-from-its-binary
-- - https://en.wikipedia.org/wiki/JPEG#Syntax_and_structure
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.jpeg_size(handle)
	-- skip SOI marker (2 bytes)
	handle:seek("cur", 2)
	local width, height
	while true do
		local byte = handle:read(1)
		if not byte then
			break
		end
		-- start of marker
		if byte == "\xFF" then
			local marker_type = handle:read(1)
			-- C0: baseline DCT-based JPEG
			-- C2: progressive DCT-based JPEG
			if marker_type == "\xC0" or marker_type == "\xC2" then
				local chunk_data = handle:read(7)
				height = string.unpack(">I2", chunk_data:sub(4, 5))
				width = string.unpack(">I2", chunk_data:sub(6, 7))
				break
			else
				-- skip over segment
				local len = string.unpack(">I2", handle:read(2))
				handle:seek("cur", len - 2)
			end
		end
	end
	if not width and not height then
		return 0,
			0,
			string.format("Invalid JPEG file: could not find width/height (width=%q, height=%q)", width, height)
	end
	return width, height, nil
end

-- get width and height of a gif file
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA
-- * 6: "GIFnnn" where nnn is the version (87a or 89a)
-- * 2: width
-- * 2: height
--
-- total needed: 10
-- width offset: 7
-- height offset: 9
--
-- references:
-- - https://en.wikipedia.org/wiki/GIF#Example_GIF_file
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.gif_size(handle)
	local data = handle:read(10)
	if #data < 10 then
		return 0, 0, string.format("Invalid GIF file: malformed header (too short) (%q)", data)
	end
	local width = string.unpack("<I2", data:sub(7, 8))
	local height = string.unpack("<I2", data:sub(9, 10))
	return width, height, nil
end
-- }}}

return Public
