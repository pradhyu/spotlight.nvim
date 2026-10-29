local config = require("spotlight.config")
local badges = require("spotlight.ui.badges")

local M = {}

local SIDEBAR_FTS = {
  ["neo-tree"] = true,
  ["NvimTree"] = true,
  ["Trouble"] = true,
  ["qf"] = true,
  ["supermarkdown_toc"] = true,
  ["aerial"] = true,
  ["Outline"] = true,
}

---Get all eligible target windows in the current tabpage
---@param opts? table
---@return SpotlightBadgeItem[]
function M.get_pickable_windows(opts)
  opts = vim.tbl_deep_extend("force", config.options.picker or {}, opts or {})
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local keys = opts.keys or "asdfgqwertzxcvbyuiopnm"
  local items = {}
  local key_idx = 1

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      local win_cfg = vim.api.nvim_win_get_config(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype or ""

      local is_float = (win_cfg.relative and win_cfg.relative ~= "")
      local is_focusable = (win_cfg.focusable ~= false)
      local is_badge = (ft == "spotlight_badge" or ft == "spotlight_grid" or ft == "spotlight_hud")
      local is_sidebar = SIDEBAR_FTS[ft] == true

      if not is_badge and is_focusable then
        if (not is_float or opts.include_floating) and (not is_sidebar or opts.include_sidebars) then
          local pos = vim.api.nvim_win_get_position(win)
          local w = vim.api.nvim_win_get_width(win)
          local h = vim.api.nvim_win_get_height(win)
          local key = keys:sub(key_idx, key_idx)
          if key == "" then
            key = tostring(key_idx)
          end
          key_idx = key_idx + 1

          table.insert(items, {
            win = win,
            buf = buf,
            key = key,
            label = badges.get_window_label(win),
            x = pos[2] + w / 2,
            y = pos[1] + h / 2,
          })
        end
      end
    end
  end

  return items
end

---Find the best directional neighbor window index for h/j/k/l movement
---@param items SpotlightBadgeItem[]
---@param cur_idx integer
---@param dir "left"|"right"|"up"|"down"
---@return integer next_idx
function M.find_directional_neighbor(items, cur_idx, dir)
  if #items <= 1 then
    return cur_idx
  end
  local cur = items[cur_idx]
  if not cur then
    return 1
  end

  local best_idx = nil
  local best_score = math.huge

  for idx, item in ipairs(items) do
    if idx ~= cur_idx then
      local dx = item.x - cur.x
      local dy = item.y - cur.y
      local valid = false
      local score = math.huge

      if dir == "left" and dx < -1 then
        valid = true
        score = math.abs(dx) + math.abs(dy) * 2.0
      elseif dir == "right" and dx > 1 then
        valid = true
        score = math.abs(dx) + math.abs(dy) * 2.0
      elseif dir == "up" and dy < -0.5 then
        valid = true
        score = math.abs(dy) * 2.0 + math.abs(dx)
      elseif dir == "down" and dy > 0.5 then
        valid = true
        score = math.abs(dy) * 2.0 + math.abs(dx)
      end

      if valid and score < best_score then
        best_score = score
        best_idx = idx
      end
    end
  end

  if best_idx then
    return best_idx
  end

  -- Fallback cyclic wrap when at the edge of the screen
  if dir == "left" or dir == "up" then
    return ((cur_idx - 2) % #items) + 1
  else
    return (cur_idx % #items) + 1
  end
end

---Execute the chosen window action
---@param origin_win integer
---@param target SpotlightBadgeItem
---@param action "jump"|"swap"|"close"|"pull"
function M.apply_action(origin_win, target, action)
  if not target or not vim.api.nvim_win_is_valid(target.win) then
    return
  end

  local opts = config.options.picker or {}

  if action == "jump" then
    vim.api.nvim_set_current_win(target.win)
    local buf = vim.api.nvim_win_get_buf(target.win)
    if opts.auto_terminal_insert and vim.bo[buf].buftype == "terminal" then
      vim.cmd("startinsert")
    end
  elseif action == "swap" then
    if origin_win == target.win or not vim.api.nvim_win_is_valid(origin_win) then
      return
    end
    local buf_orig = vim.api.nvim_win_get_buf(origin_win)
    local cur_orig = vim.api.nvim_win_get_cursor(origin_win)
    local buf_targ = vim.api.nvim_win_get_buf(target.win)
    local cur_targ = vim.api.nvim_win_get_cursor(target.win)

    vim.api.nvim_win_set_buf(origin_win, buf_targ)
    pcall(vim.api.nvim_win_set_cursor, origin_win, cur_targ)
    vim.api.nvim_win_set_buf(target.win, buf_orig)
    pcall(vim.api.nvim_win_set_cursor, target.win, cur_orig)
    vim.api.nvim_set_current_win(target.win)
  elseif action == "close" then
    local wins = M.get_pickable_windows()
    if #wins <= 1 then
      vim.notify("[Spotlight] Cannot close the last window in tab", vim.log.levels.WARN)
      return
    end
    pcall(vim.api.nvim_win_close, target.win, false)
  elseif action == "pull" then
    if vim.api.nvim_win_is_valid(origin_win) then
      local buf_targ = vim.api.nvim_win_get_buf(target.win)
      vim.api.nvim_win_set_buf(origin_win, buf_targ)
      vim.api.nvim_set_current_win(origin_win)
    end
  end
end

---Interactive Visual Window & Split Picker (supports both h/j/k/l + <CR> and badge keys)
---@param opts? { action?: "jump"|"swap"|"close"|"pull" }
---@return integer|nil target_win
function M.pick_window(opts)
  opts = opts or {}
  local action = opts.action or "jump"

  -- If invoked from Terminal mode, exit to Normal mode first
  local mode = vim.api.nvim_get_mode().mode
  if mode == "t" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  end

  local origin_win = vim.api.nvim_get_current_win()
  local items = M.get_pickable_windows(opts)

  if #items == 0 then
    return nil
  end
  if #items == 1 and action == "jump" then
    vim.notify("[Spotlight] Only 1 window open in current tab", vim.log.levels.INFO)
    return items[1].win
  end

  -- Start highlight on the next split (or current split if only 1)
  local active_idx = 1
  for i, item in ipairs(items) do
    if item.win == origin_win then
      active_idx = (i % #items) + 1
      break
    end
  end

  local key_map = {}
  for i, item in ipairs(items) do
    key_map[item.key] = i
  end

  local floats = badges.render_badges(items, active_idx, action)
  vim.cmd("redraw")
  vim.api.nvim_echo({
    { " 🔦 Spotlight Picker ", "SpotlightGridTitle" },
    {
      string.format(
        " [%s]  [h/j/k/l] Move + [<CR>] Confirm  [%s] Instant Badge  [S] Swap  [x] Close  [p] Pull  [Esc] Cancel",
        action:upper(),
        items[1].key .. ".." .. items[#items].key
      ),
      "Comment",
    },
  }, false, {})

  local chosen_target = nil
  local chosen_action = action

  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or ch == "\27" or ch == "\3" or ch == "q" then
      break
    end

    if ch == "\r" or ch == "\n" or ch == " " then
      chosen_target = items[active_idx]
      break
    elseif config.options.picker.directional_keys ~= false and (ch == "h" or ch == vim.keycode("<Left>")) then
      active_idx = M.find_directional_neighbor(items, active_idx, "left")
      floats = badges.render_badges(items, active_idx, chosen_action, floats)
      vim.cmd("redraw")
    elseif config.options.picker.directional_keys ~= false and (ch == "l" or ch == vim.keycode("<Right>")) then
      active_idx = M.find_directional_neighbor(items, active_idx, "right")
      floats = badges.render_badges(items, active_idx, chosen_action, floats)
      vim.cmd("redraw")
    elseif config.options.picker.directional_keys ~= false and (ch == "k" or ch == vim.keycode("<Up>")) then
      active_idx = M.find_directional_neighbor(items, active_idx, "up")
      floats = badges.render_badges(items, active_idx, chosen_action, floats)
      vim.cmd("redraw")
    elseif config.options.picker.directional_keys ~= false and (ch == "j" or ch == vim.keycode("<Down>")) then
      active_idx = M.find_directional_neighbor(items, active_idx, "down")
      floats = badges.render_badges(items, active_idx, chosen_action, floats)
      vim.cmd("redraw")
    elseif ch == "\t" then
      active_idx = (active_idx % #items) + 1
      floats = badges.render_badges(items, active_idx, chosen_action, floats)
      vim.cmd("redraw")
    elseif ch == "S" then
      chosen_target = items[active_idx]
      chosen_action = "swap"
      break
    elseif ch == "X" or (ch == "x" and not key_map["x"]) then
      chosen_target = items[active_idx]
      chosen_action = "close"
      break
    elseif ch == "P" or (ch == "p" and not key_map["p"]) then
      chosen_target = items[active_idx]
      chosen_action = "pull"
      break
    elseif key_map[ch] then
      chosen_target = items[key_map[ch]]
      break
    end
  end

  badges.clear_badges(floats)
  vim.api.nvim_echo({}, false, {})
  vim.cmd("redraw")

  if chosen_target then
    M.apply_action(origin_win, chosen_target, chosen_action)
    return chosen_target.win
  end
  return nil
end

return M
