-- Headless test suite for spotlight.nvim
-- Run with: nvim --headless --clean -u NONE -c "set rtp+=~/git/spotlight.nvim" -c "luafile ~/git/spotlight.nvim/tests/test_spotlight_spec.lua" -c "qa!"

local spotlight = require("spotlight")
local picker = require("spotlight.core.picker")
local grid = require("spotlight.core.grid")
local zoom = require("spotlight.core.zoom")
local dim = require("spotlight.core.dim")

spotlight.setup()

local passed = 0
local failed = 0

local function assert_eq(actual, expected, msg)
  if actual == expected then
    passed = passed + 1
    print("  [PASS] " .. msg)
  else
    failed = failed + 1
    print(string.format("  [FAIL] %s (expected %s, got %s)", msg, vim.inspect(expected), vim.inspect(actual)))
  end
end

print("=== Running spotlight.nvim Headless Test Suite ===")

-- Test 1: Multi-split window enumeration & non-conflicting badge keys (no h/j/k/l)
vim.cmd("enew")
local b1 = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(b1, "alpha.lua")
vim.cmd("vsplit")
vim.cmd("enew")
local b2 = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(b2, "beta.lua")
vim.cmd("split")
vim.cmd("enew")
local b3 = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(b3, "gamma.lua")

local items = picker.get_pickable_windows()
assert_eq(#items, 3, "Enumerates all 3 splits in current tabpage")
for _, item in ipairs(items) do
  local has_hjkl = item.key:match("[hjkl]") ~= nil
  assert_eq(has_hjkl, false, "Badge key '" .. item.key .. "' excludes h/j/k/l")
end

-- Test 2: Directional neighbor resolution (h/j/k/l geometry)
local neighbor_right = picker.find_directional_neighbor(items, 1, "right")
assert_eq(neighbor_right ~= 1, true, "Directional 'l' (right) finds neighboring split")

-- Test 3: Swap action between two windows
local w1 = items[1].win
local w2 = items[2].win
local orig_b1 = vim.api.nvim_win_get_buf(w1)
local orig_b2 = vim.api.nvim_win_get_buf(w2)
picker.apply_action(w1, items[2], "swap")
assert_eq(vim.api.nvim_win_get_buf(w1), orig_b2, "Swap action places target buffer in origin window")
assert_eq(vim.api.nvim_win_get_buf(w2), orig_b1, "Swap action places origin buffer in target window")

-- Test 4: Ghostty-style Split Zoom & Restoration
local z_on = zoom.toggle_zoom("native")
assert_eq(z_on, true, "toggle_zoom activates zoom when multiple splits exist")
assert_eq(zoom.is_zoomed(), true, "is_zoomed() reports true while zoomed")
local z_off = zoom.toggle_zoom("native")
assert_eq(z_off, false, "toggle_zoom restores split layout on second call")
assert_eq(zoom.is_zoomed(), false, "is_zoomed() reports false after unzoom")

-- Test 5: Tab-scoped vs All-tabs Buffer Exposé card collection
local tab1_cards = grid.get_cards({ scope = "tab" })
assert_eq(#tab1_cards >= 3, true, "Exposé grid collects buffers in Tab 1")

-- Test 6: Multi-buffer layout composition (2x2 Grid & Main+Stack)
grid.compose_layout({ b1, b2, b3 }, "main_left")
local wins_after = picker.get_pickable_windows()
assert_eq(#wins_after, 3, "compose_layout('main_left') creates 3-pane Main+Stack layout")

-- Test 7: Unfocused split dimming toggle
local dim_off = dim.toggle_dim("off")
assert_eq(dim_off, false, "toggle_dim('off') disables dimming")
local dim_on = dim.toggle_dim("on")
assert_eq(dim_on, true, "toggle_dim('on') enables dimming")

print(string.format("=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
  vim.cmd("cquit 1")
end
