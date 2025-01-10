---@class BagmanUtils
local M = {}
-- additional table methods
M.table = {}

-- returns a shallow copy of a table. this means table values will still be
-- by reference.
-- used for tables containing atomic types
---@param tbl table
---@return table tbl_copy
function M.table.shallow_copy(tbl)
    local tbl_copy = {}
    for k, v in pairs(tbl) do
        tbl_copy[k] = v
    end
    return tbl_copy
end

-- returns a deep copy of a table.
-- used for when tables contain other tables.
-- credits: https://gist.github.com/tylerneylon/81333721109155b2d244
---@param tbl table
---@param seen? table whether we saw this table before, to avoid inf recursion
---@return table tbl_copy
function M.table.deep_copy(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end
    if seen and seen[tbl] then
        return seen[tbl]
    end

    local s = seen or {}
    local res = {}
    s[tbl] = res
    for k, v in pairs(tbl) do
        res[M.table.deep_copy(k, s)] = M.table.deep_copy(v, s)
    end
    return setmetatable(res, getmetatable(tbl))
end

return M
