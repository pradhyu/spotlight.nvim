local config = require("spotlight.config")

local M = {
  ---@type table<integer, string> win_handle -> original winhighlight before dimming
  _orig_winhl = {},
}

---Check if a window should be excluded from dimming
---@param win integer
---@return boolean
function M.is_excluded(win)
  if not vim.api.nvim_win_is_valid(win) then
    return true
  end
  local win_cfg = vim.api.nvim_win_get_config(win)
  if win_cfg.relative and win_cfg.relative ~= "" then
    return true
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype or ""
  local bt = vim.bo[buf].buftype or ""
  local dim_cfg = config.options.dim or {}

  if bt == "terminal" and dim_cfg.dim_terminal == false then
    return true
  end

  for _, ex in ipairs(dim_cfg.excluded_filetypes or {}) do
    if ft == ex then
      return true
    end
  end
  return false
end

---Refresh dimming across all windows in the current tabpage
function M.refresh()
  local dim_cfg = config.options.dim or {}
  local cur_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)

  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) then
      if not dim_cfg.enabled or w == cur_win or M.is_excluded(w) or #wins <= 1 then
        if M._orig_winhl[w] ~= nil then
          vim.wo[w].winhighlight = M._orig_winhl[w]
          M._orig_winhl[w] = nil
        end
      else
        if M._orig_winhl[w] == nil then
          M._orig_winhl[w] = vim.wo[w].winhighlight or ""
        end
        vim.wo[w].winhighlight = "Normal:SpotlightDimNormal,NormalNC:SpotlightDimNormal,LineNr:SpotlightDimLineNr,WinSeparator:SpotlightDimWinSeparator"
      end
    end
  end
end

---Set or toggle unfocused split dimming
---@param state? "on"|"off"|"toggle"
---@return boolean enabled
function M.toggle_dim(state)
  local dim_cfg = config.options.dim
  if state == "on" then
    dim_cfg.enabled = true
  elseif state == "off" then
    dim_cfg.enabled = false
  else
    dim_cfg.enabled = not dim_cfg.enabled
  end
  M.refresh()
  return dim_cfg.enabled
end

return M
