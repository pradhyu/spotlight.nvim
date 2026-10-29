local config = require("spotlight.config")

local M = {}

---Check if a window is a fixed sidebar or floating window
---@param win integer
---@return boolean
function M.is_fixed_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return true
  end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= "" then
    return true
  end
  if vim.wo[win].winfixwidth or vim.wo[win].winfixheight then
    return true
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype or ""
  local res_cfg = config.options.resize or {}
  for _, ex in ipairs(res_cfg.excluded_filetypes or {}) do
    if ft == ex then
      return true
    end
  end
  return false
end

---Apply golden-ratio sizing to the currently focused window if enabled
function M.apply_golden_ratio()
  local res_cfg = config.options.resize or {}
  if not res_cfg.golden_ratio then
    return
  end
  local cur_win = vim.api.nvim_get_current_win()
  if M.is_fixed_window(cur_win) then
    return
  end

  local normal_wins = 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not M.is_fixed_window(w) then
      normal_wins = normal_wins + 1
    end
  end
  if normal_wins <= 1 then
    return
  end

  local target_w = math.floor(vim.o.columns * (res_cfg.focused_width_ratio or 0.62))
  local target_h = math.floor((vim.o.lines - 2) * (res_cfg.focused_height_ratio or 0.62))
  pcall(vim.api.nvim_win_set_width, cur_win, math.max(20, target_w))
  pcall(vim.api.nvim_win_set_height, cur_win, math.max(8, target_h))
end

---Toggle or set automatic golden-ratio split resizing
---@param state? "on"|"off"|"toggle"
---@return boolean enabled
function M.toggle_golden(state)
  local res_cfg = config.options.resize
  if state == "on" then
    res_cfg.golden_ratio = true
  elseif state == "off" then
    res_cfg.golden_ratio = false
  else
    res_cfg.golden_ratio = not res_cfg.golden_ratio
  end

  if res_cfg.golden_ratio then
    M.apply_golden_ratio()
  else
    M.equalize()
  end
  return res_cfg.golden_ratio
end

---Equalize non-fixed splits in the current tabpage
function M.equalize()
  vim.cmd("wincmd =")
end

---Smart directional split resize
---@param dir "left"|"right"|"up"|"down"
---@param step? integer
function M.resize_split(dir, step)
  local res_cfg = config.options.resize or {}
  step = step or res_cfg.step_size or 5
  local cur_win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(cur_win) then
    return
  end
  if dir == "left" then
    vim.api.nvim_win_set_width(cur_win, math.max(10, vim.api.nvim_win_get_width(cur_win) - step))
  elseif dir == "right" then
    vim.api.nvim_win_set_width(cur_win, vim.api.nvim_win_get_width(cur_win) + step)
  elseif dir == "up" then
    vim.api.nvim_win_set_height(cur_win, math.max(4, vim.api.nvim_win_get_height(cur_win) - step))
  elseif dir == "down" then
    vim.api.nvim_win_set_height(cur_win, vim.api.nvim_win_get_height(cur_win) + step)
  end
end

return M
