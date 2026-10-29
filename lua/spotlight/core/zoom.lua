local config = require("spotlight.config")

local M = {
  ---@type table<integer, { restcmd: string, zoomed_win: integer, float_win?: integer, badge_win?: integer, badge_buf?: integer }>
  _tab_state = {},
}

---Close zoom indicator badge for a tab
---@param tab integer
local function close_badge(tab)
  local st = M._tab_state[tab]
  if not st then
    return
  end
  if st.badge_win and vim.api.nvim_win_is_valid(st.badge_win) then
    pcall(vim.api.nvim_win_close, st.badge_win, true)
  end
  if st.badge_buf and vim.api.nvim_buf_is_valid(st.badge_buf) then
    pcall(vim.api.nvim_buf_delete, st.badge_buf, { force = true })
  end
  st.badge_win = nil
  st.badge_buf = nil
end

---Render a subtle top-right "🔦 SPOTLIGHT ZOOM [1/N]" badge inside the zoomed window
---@param tab integer
---@param win integer
---@param total_splits integer
local function open_badge(tab, win, total_splits)
  close_badge(tab)
  local zoom_cfg = config.options.zoom or {}
  if zoom_cfg.show_badge == false or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local text = string.format(" 🔦 SPOTLIGHT ZOOM [1/%d] ", total_splits)
  local width = vim.fn.strdisplaywidth(text)
  local win_w = vim.api.nvim_win_get_width(win)

  local bbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[bbuf].buftype = "nofile"
  vim.bo[bbuf].bufhidden = "wipe"
  vim.bo[bbuf].filetype = "spotlight_badge"
  vim.api.nvim_buf_set_lines(bbuf, 0, -1, false, { text })
  vim.bo[bbuf].modifiable = false

  local bwin = vim.api.nvim_open_win(bbuf, false, {
    relative = "win",
    win = win,
    row = 0,
    col = math.max(0, win_w - width - 2),
    width = width,
    height = 1,
    style = "minimal",
    focusable = false,
    noautocmd = true,
    zindex = 220,
  })
  vim.wo[bwin].winhighlight = "Normal:SpotlightZoomBadge"

  if M._tab_state[tab] then
    M._tab_state[tab].badge_win = bwin
    M._tab_state[tab].badge_buf = bbuf
  end
end

---Check if the given tab (or current tab) is currently zoomed
---@param tab? integer
---@return boolean
function M.is_zoomed(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local st = M._tab_state[tab]
  return st ~= nil
end

---Unzoom the given tabpage and restore original split proportions
---@param tab? integer
function M.unzoom(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local st = M._tab_state[tab]
  if not st then
    return
  end

  close_badge(tab)

  if st.float_win and vim.api.nvim_win_is_valid(st.float_win) then
    local cur_pos = vim.api.nvim_win_get_cursor(st.float_win)
    pcall(vim.api.nvim_win_close, st.float_win, true)
    if st.zoomed_win and vim.api.nvim_win_is_valid(st.zoomed_win) then
      vim.api.nvim_set_current_win(st.zoomed_win)
      pcall(vim.api.nvim_win_set_cursor, st.zoomed_win, cur_pos)
    end
  elseif st.restcmd then
    pcall(vim.cmd, st.restcmd)
  end

  M._tab_state[tab] = nil
end

---Toggle Ghostty-style Split Zoom on the active window
---@param mode_override? "native"|"float"
---@return boolean zoomed
function M.toggle_zoom(mode_override)
  local mode_now = vim.api.nvim_get_mode().mode
  if mode_now == "t" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  end

  local tab = vim.api.nvim_get_current_tabpage()
  if M.is_zoomed(tab) then
    M.unzoom(tab)
    return false
  end

  -- Count non-floating windows in current tab
  local normal_wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_is_valid(w) then
      local cfg = vim.api.nvim_win_get_config(w)
      if not cfg.relative or cfg.relative == "" then
        table.insert(normal_wins, w)
      end
    end
  end

  local zoom_cfg = config.options.zoom or {}
  local zoom_mode = mode_override or zoom_cfg.mode or "native"

  if #normal_wins <= 1 and zoom_mode == "native" then
    vim.notify("[Spotlight] Only 1 split open in tab", vim.log.levels.INFO)
    return false
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  local cur_pos = vim.api.nvim_win_get_cursor(cur_win)

  if zoom_mode == "float" then
    local scale = zoom_cfg.float_scale or 0.94
    local w = math.max(40, math.floor(vim.o.columns * scale))
    local h = math.max(12, math.floor((vim.o.lines - 2) * scale))
    local r = math.max(0, math.floor((vim.o.lines - h) / 2) - 1)
    local c = math.max(0, math.floor((vim.o.columns - w) / 2))

    local fwin = vim.api.nvim_open_win(cur_buf, true, {
      relative = "editor",
      row = r,
      col = c,
      width = w,
      height = h,
      border = "rounded",
      title = " 🔦 Spotlight Zoom ",
      title_pos = "center",
      zindex = 180,
    })
    pcall(vim.api.nvim_win_set_cursor, fwin, cur_pos)
    M._tab_state[tab] = {
      restcmd = nil,
      zoomed_win = cur_win,
      float_win = fwin,
    }
    open_badge(tab, fwin, #normal_wins)
  else
    local restcmd = vim.fn.winrestcmd()
    M._tab_state[tab] = {
      restcmd = restcmd,
      zoomed_win = cur_win,
    }
    vim.cmd("wincmd |")
    vim.cmd("wincmd _")
    open_badge(tab, cur_win, #normal_wins)
  end

  return true
end

---Handle WinEnter event to auto-unzoom if configured
function M.on_win_enter()
  local zoom_cfg = config.options.zoom or {}
  if zoom_cfg.auto_unzoom_on_leave == false then
    return
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local st = M._tab_state[tab]
  if not st then
    return
  end
  local cur_win = vim.api.nvim_get_current_win()
  local cfg = vim.api.nvim_win_get_config(cur_win)
  if cfg.relative and cfg.relative ~= "" and cur_win ~= st.float_win then
    return
  end
  local active_zoom_win = st.float_win or st.zoomed_win
  if cur_win ~= active_zoom_win then
    M.unzoom(tab)
  end
end

return M
