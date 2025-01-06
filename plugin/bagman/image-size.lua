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
	elseif magic:sub(1, 2) == "BM" then
		width, height, err = private.bmp_size(handle)
	elseif magic:sub(1, 4) == "\0\0\1\0" then
		width, height, err = private.ico_size(handle)
	elseif magic:sub(1, 2) == "II" or magic:sub(1, 2) == "MM" then
		width, height, err = private.tiff_size(handle)
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

-- get width and height of a bmp file
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA:
-- * 2: "BM"
-- * 4: size of bmp file
-- * 4: unused
-- * 4: offset where bitmap data can be found
-- * 12: DIB header
--   * 4: size (bytes) of dib header
--   * 4: width
--   * 4: height
--
-- total needed: 26
-- width offset: 19
-- height offset: 23
--
-- references:
-- - https://en.wikipedia.org/wiki/BMP_file_format#Example_1
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.bmp_size(handle)
	local data = handle:read(26)
	if #data < 26 then
		return 0, 0, string.format("Invalid BMP file: malformed header (too short) (%q)", data)
	end
	local width = string.unpack("<I4", data:sub(19, 22))
	local height = string.unpack("<I4", data:sub(23, 26))
	return width, height, nil
end

-- get width and height of an ico file. This only gets the dimensions of the
-- first image in the ico file.
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA:
-- * 4: "\0\0\1\0"
-- * 2: number of images in file
-- * 2: image directory
--   * 2: entry 1
--     * 1: width (from 0 to 255, 0 means 256)
--     * 1: height (from 0 to 255, 0 means 256)
--
-- total needed: 8
-- width offset: 7
-- height offset: 8
--
-- references:
-- - https://en.wikipedia.org/wiki/ICO_(file_format)#Outline
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.ico_size(handle)
	local data = handle:read(8)
	local num_images = string.unpack("<I2", data:sub(5, 6))
	if num_images == 0 then
		return 0, 0, "Invalid ICO file: no images found"
	end

	local width = data:byte(7)
	if width == 0 then
		width = 256
	end
	local height = data:byte(8)
	if height == 0 then
		height = 256
	end
	return width, height, nil
end

-- get width and height of a tiff file. This only gets the dimensions of the
-- first image in the TIFF file.
-- Details:
-- BYTE ORDER: variable
--
-- DATA
-- * 4: "II"=little-endian, or "MM"=big-endian
-- * 4: offset to first IFD entry
-- ...goto first IFD
-- * 14: first IFD
--   * 2: number of entries
--   * 12: entry
--     * 2: tag (what we want is 256=width and 257=height)
--     * 2: field type
--     * 4: number of values in entry
--     * 4: value
--
-- total needed: variable
-- total entry size needed: 14
-- width offset from entry tagged 256: 9
-- height offset from entry tagged 257: 9
--
-- references:
-- - https://www.itu.int/itudoc/itu-t/com16/tiff-fx/docs/tiff6.pdf
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.tiff_size(handle)
	local header = handle:read(4)
	local byte_order
	if header:sub(1, 2) == "II" then
		byte_order = "<"
	elseif header:sub(1, 2) == "MM" then
		byte_order = ">"
	else
		return 0,
			0,
			string.format(
				"UNEXPECTED ERROR: tiff magic number should be checked beforehand ('%q' is not 'II' or 'MM')",
				header:sub(1, 2)
			)
	end

	local ifd_offset = string.unpack(byte_order .. "I4", handle:read(4))
	handle:seek("set", ifd_offset)

	local num_entries = string.unpack(byte_order .. "I2", handle:read(2))
	local width, height
	for _ = 1, num_entries do
		local entry = handle:read(12)
		if not entry or #entry < 12 then
			return 0, 0, string.format("Invalid TIFF file: invalid IFD entry (%q)", entry)
		end

		local tag = string.unpack(byte_order .. "I2", entry:sub(1, 2))
		if tag == 256 then
			width = string.unpack(byte_order .. "I4", entry:sub(9, 12))
		elseif tag == 257 then
			height = string.unpack(byte_order .. "I4", entry:sub(9, 12))
		end
		if width and height then
			break
		end
	end
	if not width or not height then
		return 0, 0, string.format("Invalid TIFF file: width/height tag not found (width=%q, height=%q)", width, height)
	end
	return width, height, nil
end
-- }}}

return Public
