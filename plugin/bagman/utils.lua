local M = {}
-- additional table methods
M.table = {}

-- returns a shallow copy of a table. this means table values will still be
-- by reference.
---@param tbl table
---@return table tbl_copy
function M.table.shallow_copy(tbl)
	local tbl_copy = {}
	for k, v in pairs(tbl) do
		tbl_copy[k] = v
	end
	return tbl_copy
end

return M
