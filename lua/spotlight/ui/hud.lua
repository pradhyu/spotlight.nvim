local config = require("spotlight.config")
local picker = require("spotlight.core.picker")
local grid = require("spotlight.core.grid")
local zoom = require("spotlight.core.zoom")
local dim = require("spotlight.core.dim")
local resize = require("spotlight.core.resize")

local M = {}

---Open the interactive Spotlight Control Center HUD
function M.open_hud()
  local w = 64
  local h = 16
  local row = math.max(1, math.floor((vim.o.lines - h) / 2) - 1)
  local col = math.max(1, math.floor((vim.o.columns - w) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "spotlight_hud"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = w,
    height = h,
    style = "minimal",
    border = "rounded",
    title = " 🔦 Spotlight Control Center ",
    title_pos = "center",
    zindex = 210,
  })
  vim.wo[win].winhighlight = "Normal:SpotlightGridNormal,FloatBorder:SpotlightGridBorder,FloatTitle:SpotlightGridTitle"

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local is_dim = config.options.dim.enabled and "ON ✅" or "OFF ❌"
    local is_gold = config.options.resize.golden_ratio and "ON ✅" or "OFF ❌"
    local is_zm = zoom.is_zoomed() and "ZOOMED 🔦" or "Normal"
    local num_splits = #picker.get_pickable_windows()
    local num_cards = #grid.get_cards({ scope = "tab" })

    local lines = {
      string.format("  Active Tab Splits: %-4d   Tab Buffers: %-4d   State: %s", num_splits, num_cards, is_zm),
      string.format("  Unfocused Dimming: %-8s   Golden Ratio: %s", is_dim, is_gold),
      string.rep("─", w),
      "  🎯 Visual Pickers & Exposé:",
      "    [f] Visual Split Picker (h/j/k/l + Badges)",
      "    [b] 2D Buffer Exposé Grid (Current Tab)",
      "    [B] 2D Buffer Exposé Grid (All Tabs)",
      "    [s] Swap Split With Target       [x] Close Target Split",
      "",
      "  📐 Spotlight Zoom, Dimming & Layouts:",
      "    [z] Toggle Ghostty Split Zoom    [d] Toggle Split Dimming",
      "    [g] Toggle Golden-Ratio Resize   [=] Equalize All Splits",
      "    [v] Tile Buffers (Columns)       [m] Tile (Main + Stack)",
      string.rep("─", w),
      "  Press hotkey to execute or [q] / [<Esc>] to close",
    }

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end

  render()

  local function close_hud()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", close_hud, opts)
  vim.keymap.set("n", "<Esc>", close_hud, opts)
  vim.keymap.set("n", "f", function()
    close_hud()
    picker.pick_window({ action = "jump" })
  end, opts)
  vim.keymap.set("n", "b", function()
    close_hud()
    grid.open_grid({ scope = "tab" })
  end, opts)
  vim.keymap.set("n", "B", function()
    close_hud()
    grid.open_grid({ scope = "all" })
  end, opts)
  vim.keymap.set("n", "s", function()
    close_hud()
    picker.pick_window({ action = "swap" })
  end, opts)
  vim.keymap.set("n", "x", function()
    close_hud()
    picker.pick_window({ action = "close" })
  end, opts)
  vim.keymap.set("n", "z", function()
    close_hud()
    zoom.toggle_zoom()
  end, opts)
  vim.keymap.set("n", "d", function()
    dim.toggle_dim("toggle")
    render()
  end, opts)
  vim.keymap.set("n", "g", function()
    resize.toggle_golden("toggle")
    render()
  end, opts)
  vim.keymap.set("n", "=", function()
    close_hud()
    resize.equalize()
  end, opts)
  vim.keymap.set("n", "v", function()
    close_hud()
    local cards = grid.get_cards({ scope = "tab" })
    local bufs = vim.tbl_map(function(c) return c.buf end, cards)
    grid.compose_layout(bufs, "vsplit")
  end, opts)
  vim.keymap.set("n", "m", function()
    close_hud()
    local cards = grid.get_cards({ scope = "tab" })
    local bufs = vim.tbl_map(function(c) return c.buf end, cards)
    grid.compose_layout(bufs, "main_left")
  end, opts)
end

return M
