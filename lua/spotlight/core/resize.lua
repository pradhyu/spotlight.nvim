local config = require("spotlight.config")

local M = {}

---Check if a window is a fixed sidebar, bottom bar, non-user buffer, or floating window
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
  if not vim.bo[buf].buflisted and vim.bo[buf].buftype ~= "" and vim.bo[buf].buftype ~= "terminal" then
    return true
  end
  local bt = vim.bo[buf].buftype or ""
  local ft = vim.bo[buf].filetype or ""
  local res_cfg = config.options.resize or {}
  for _, ex_bt in ipairs(res_cfg.excluded_buftypes or { "nofile", "quickfix", "prompt", "help", "acwrite" }) do
    if bt == ex_bt then
      return true
    end
  end
  for _, ex in ipairs(res_cfg.excluded_filetypes or {}) do
    if ft == ex then
      return true
    end
  end
  return false
end

---Temporarily lock winfixwidth/winfixheight on fixed/non-user windows while running `fn`
---@param wins integer[]
---@param fn fun()
local function with_locked_fixed_windows(wins, fn)
  local saved = {}
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) and M.is_fixed_window(w) then
      saved[w] = {
        wfw = vim.wo[w].winfixwidth,
        wfh = vim.wo[w].winfixheight,
        width = vim.api.nvim_win_get_width(w),
        height = vim.api.nvim_win_get_height(w),
      }
      vim.wo[w].winfixwidth = true
      vim.wo[w].winfixheight = true
    end
  end
  pcall(fn)
  for w, st in pairs(saved) do
    if vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_set_width, w, st.width)
      pcall(vim.api.nvim_win_set_height, w, st.height)
      vim.wo[w].winfixwidth = st.wfw
      vim.wo[w].winfixheight = st.wfh
    end
  end
end

---Apply golden-ratio sizing to the currently focused user window if enabled
function M.apply_golden_ratio()
  local res_cfg = config.options.resize or {}
  if not res_cfg.golden_ratio then
    return
  end
  local cur_win = vim.api.nvim_get_current_win()
  if M.is_fixed_window(cur_win) then
    return
  end

  local all_wins = vim.api.nvim_tabpage_list_wins(0)
  local normal_wins = {}
  for _, w in ipairs(all_wins) do
    if not M.is_fixed_window(w) then
      table.insert(normal_wins, w)
    end
  end
  if #normal_wins <= 1 then
    return
  end

  -- Determine whether other user windows exist horizontally and/or vertically
  local cur_pos = vim.api.nvim_win_get_position(cur_win)
  local has_horiz_neighbor = false
  local has_vert_neighbor = false
  for _, w in ipairs(normal_wins) do
    if w ~= cur_win then
      local pos = vim.api.nvim_win_get_position(w)
      if pos[2] ~= cur_pos[2] then
        has_horiz_neighbor = true
      end
      if pos[1] ~= cur_pos[1] then
        has_vert_neighbor = true
      end
    end
  end

  with_locked_fixed_windows(all_wins, function()
    if has_horiz_neighbor then
      local target_w = math.floor(vim.o.columns * (res_cfg.focused_width_ratio or 0.62))
      pcall(vim.api.nvim_win_set_width, cur_win, math.max(20, target_w))
    end
    if has_vert_neighbor then
      local target_h = math.floor((vim.o.lines - 2) * (res_cfg.focused_height_ratio or 0.62))
      pcall(vim.api.nvim_win_set_height, cur_win, math.max(8, target_h))
    end
  end)
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
  local all_wins = vim.api.nvim_tabpage_list_wins(0)
  with_locked_fixed_windows(all_wins, function()
    vim.cmd("wincmd =")
  end)
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
