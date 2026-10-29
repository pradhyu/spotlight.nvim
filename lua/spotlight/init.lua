local config = require("spotlight.config")
local picker = require("spotlight.core.picker")
local grid = require("spotlight.core.grid")
local zoom = require("spotlight.core.zoom")
local dim = require("spotlight.core.dim")
local resize = require("spotlight.core.resize")
local hud = require("spotlight.ui.hud")
local statusline = require("spotlight.ui.statusline")

local M = {}

---Initialize spotlight.nvim with optional user overrides
---@param opts? table
function M.setup(opts)
  config.setup(opts)

  local augroup = vim.api.nvim_create_augroup("SpotlightNvim", { clear = true })

  vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "TabEnter", "WinClosed" }, {
    group = augroup,
    callback = function()
      vim.schedule(function()
        zoom.on_win_enter()
        dim.refresh()
        resize.apply_golden_ratio()
      end)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function()
      config.setup_highlights()
      dim.refresh()
    end,
  })

  dim.refresh()
end

-- Public API delegations
M.pick_window = picker.pick_window
M.swap_window = function()
  return picker.pick_window({ action = "swap" })
end
M.close_window = function()
  return picker.pick_window({ action = "close" })
end
M.pull_buffer = function()
  return picker.pick_window({ action = "pull" })
end

M.open_grid = grid.open_grid
M.compose_layout = grid.compose_layout
M.get_cards = grid.get_cards

M.toggle_zoom = zoom.toggle_zoom
M.unzoom = zoom.unzoom
M.is_zoomed = zoom.is_zoomed

M.toggle_dim = dim.toggle_dim
M.refresh_dim = dim.refresh

M.toggle_golden = resize.toggle_golden
M.equalize = resize.equalize
M.resize_split = resize.resize_split

M.open_hud = hud.open_hud
M.status = statusline.status

return M
