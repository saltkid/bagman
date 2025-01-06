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
	elseif
		magic:sub(1, 2) == "P1"
		or magic:sub(1, 2) == "P2"
		or magic:sub(1, 2) == "P3"
		or magic:sub(1, 2) == "P4"
		or magic:sub(1, 2) == "P5"
		or magic:sub(1, 2) == "P6"
	then
		width, height, err = private.pnm_size(handle)
	elseif magic:sub(1, 4) == "DDS " then
		width, height, err = private.dds_size(handle)
	elseif private.possibly_tga(magic) then
		width, height, err = private.tga_size(handle)
	elseif magic == "farbfeld" then
		width, height, err = private.farbfeld_size(handle)
	else
		err = "Unsupported image type: " .. magic
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

-- get width and height of a pnm file (pbm, pgm, or ppm)
-- references:
-- - https://en.wikipedia.org/wiki/Netpbm#Description
--
-- Details:
-- BYTE ORDER: none, values are in plain ASCII
--
-- DATA:
-- * 2: "P{n}" where n is 1-6
-- * n: comments starting with #
-- * number after comments: width
-- * 2nd number after comments: height
--
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.pnm_size(handle)
	handle:seek("cur", 2) -- skip magic
	-- skip comments
	while true do
		local line = handle:read("*line")
		if not line then
			break
		end
		if line == "" then
			-- continue
		elseif line:sub(1, 1) ~= "#" then
			handle:seek("cur", -#line - 1)
			break
		end
	end
	local width, height = handle:read("*n"), handle:read("*n")
	if not width or not height then
		return 0, 0, string.format("Invalid PNM file: invalid pnm dimensions (width=%q, height=%q)", width, height)
	end
	return width, height, nil
end

-- get width and height of a dds file
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA:
-- * 4: "DDS "
-- * 4: header size
-- * 4: flag
-- * 4: height
-- * 4: width
--
-- total needed: 20
-- height offset: 13
-- width offset: 17
--
-- references:
-- - https://learn.microsoft.com/en-us/windows/win32/direct3ddds/dx-graphics-dds-pguide#dds-file-layout
-- - https://learn.microsoft.com/en-us/windows/win32/direct3ddds/dds-header#syntax
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.dds_size(handle)
	local header = handle:read(20)
	if #header < 20 then
		return 0, 0, string.format("Invalid DDS file: malformed header (too short) (%q)", header)
	end
	local height = string.unpack("<I4", header:sub(13, 16))
	local width = string.unpack("<I4", header:sub(17, 20))
	return width, height, nil
end

-- TGA does not have a magic number so this tries to guess if a file is a tga
-- file based on the format constraints
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA:
-- 1: ID length (0-255)
-- 1: color map type (0 or 1)
-- 1: image type (0,1,2,3,9,10,11,32,33)
--
-- references:
-- - http://www.paulbourke.net/dataformats/tga/
---@param header string header that's at least 3 bytes
---@return boolean
function private.possibly_tga(header)
	local ID_length = header:byte(1)
	local color_map_type = header:byte(2)
	local image_type = header:byte(3)
	if
		-- ID length must be (0-255)
		(ID_length >= 0 and ID_length <= 255)
		-- color map type must be in (0,1)
		and (color_map_type == 0 or color_map_type == 1)
		-- image type must be in (0,1,2,3,9,10,11,32,33)
		and (
			image_type == 0
			or image_type == 1
			or image_type == 2
			or image_type == 3
			or image_type == 9
			or image_type == 10
			or image_type == 32
			or image_type == 33
		)
	then
		return true
	end
	return false
end

-- get width and height of a tga file
-- Details:
-- BYTE ORDER: little-endian
--
-- DATA:
-- * 1: ID length (0-255)
-- * 1: color map type (0 or 1)
-- * 1: image type (0,1,2,3,9,10,11,32,33)
-- * 5: color map specification
-- * 2: X-origin
-- * 2: Y-origin
-- * 2: width
-- * 2: height
--
-- total needed: 16
-- width offset: 13
-- height offset: 15
--
-- references:
-- - http://www.paulbourke.net/dataformats/tga/
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.tga_size(handle)
	local header = handle:read(16)
	if not private.possibly_tga(header) then
		return 0, 0, string.format("Invalid TGA file: malformed header (too short) (%q)", header)
	end
	local width = string.unpack("<I2", header:sub(13, 14))
	local height = string.unpack("<I2", header:sub(15, 16))
	return width, height, nil
end

-- get width and height of a farbfeld file
-- Details:
-- BYTE ORDER: big-endian
--
-- DATA:
-- * 8: "farbfeld"
-- * 4: width
-- * 4: height
--
-- references:
-- - https://github.com/mcritchlow/farbfeld/blob/master/FORMAT
---@param handle file* file handle (do not close it). file is at least 8 bytes in length
---@return number width
---@return number height
---@return string? err error message if errored
function private.farbfeld_size(handle)
	local data = handle:read(16)
	if #data < 16 then
		return 0, 0, string.format("Invalid farbfeld file: malformed header (too short) (%q)", data)
	end
	local width = string.unpack(">I4", data:sub(9, 12))
	local height = string.unpack(">I4", data:sub(13, 16))
	return width, height, nil
end
-- }}}

return Public
