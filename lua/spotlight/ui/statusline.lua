local zoom = require("spotlight.core.zoom")
local config = require("spotlight.config")

local M = {}

---Return a statusline indicator string when zoomed or golden-ratio is active
---@return string
function M.status()
  local parts = {}
  if zoom.is_zoomed() then
    table.insert(parts, "🔦 ZOOM")
  end
  if config.options.resize and config.options.resize.golden_ratio then
    table.insert(parts, "📐 φ")
  end
  return table.concat(parts, " ")
end

return M
