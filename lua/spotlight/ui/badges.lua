local config = require("spotlight.config")

local M = {}

---@class SpotlightBadgeItem
---@field win integer Target window handle
---@field buf integer Target buffer handle
---@field key string Assigned hint badge character (e.g. "a", "s", "d")
---@field label string Short buffer label (e.g. "init.lua" or "term:agy")
---@field x number Screen center X of target window
---@field y number Screen center Y of target window

---Create a short human-readable label for a window's buffer
---@param win integer
---@return string
function M.get_window_label(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local bt = vim.bo[buf].buftype
  local ft = vim.bo[buf].filetype

  if bt == "terminal" or name:match("^term://") then
    local cmd = name:match(":([^:/]+)$") or "shell"
    return " " .. cmd
  elseif name == "" then
    return ft ~= "" and ("[" .. ft .. "]") or "[Scratch]"
  else
    local tail = vim.fn.fnamemodify(name, ":t")
    if vim.bo[buf].modified then
      tail = tail .. " ●"
    end
    return tail
  end
end

---Render or update floating badges for all candidate windows
---@param items SpotlightBadgeItem[]
---@param active_idx integer 1-based index of the currently highlighted candidate
---@param action string Current picker action ("jump"|"swap"|"close"|"pull")
---@param existing_floats? table<integer, {buf: integer, win: integer}>
---@return table<integer, {buf: integer, win: integer}> floats
function M.render_badges(items, active_idx, action, existing_floats)
  local floats = existing_floats or {}
  local opts = config.options.picker or {}
  local is_large = opts.badge_size ~= "compact"

  for idx, item in ipairs(items) do
    if vim.api.nvim_win_is_valid(item.win) then
      local is_active = (idx == active_idx)
      local win_w = vim.api.nvim_win_get_width(item.win)
      local win_h = vim.api.nvim_win_get_height(item.win)

      local label = item.label
      if #label > 16 then
        label = label:sub(1, 15) .. "…"
      end

      local action_tag = ""
      if action == "swap" then
        action_tag = "⇄ "
      elseif action == "close" then
        action_tag = "✕ "
      elseif action == "pull" then
        action_tag = "↙ "
      end

      local key_line
      if is_active then
        key_line = string.format(" ▶ [%s] %s◀ ", item.key, action_tag)
      else
        key_line = string.format("   [%s] %s  ", item.key, action_tag)
      end

      local box_w = math.max(#label + 4, #key_line + 2, 13)
      box_w = math.min(box_w, math.max(win_w - 2, 6))
      local box_h = is_large and 2 or 1

      local pad_key = math.max(0, math.floor((box_w - vim.fn.strdisplaywidth(key_line)) / 2))
      local line1 = string.rep(" ", pad_key) .. key_line
      local pad_lbl = math.max(0, math.floor((box_w - vim.fn.strdisplaywidth(label)) / 2))
      local line2 = string.rep(" ", pad_lbl) .. label

      local lines = is_large and { line1, line2 } or { line1 }

      local row, col
      if opts.position == "top_right" then
        row = 1
        col = math.max(0, win_w - box_w - 3)
      elseif opts.position == "top_left" then
        row = 1
        col = 1
      else
        row = math.max(0, math.floor((win_h - box_h) / 2) - 1)
        col = math.max(0, math.floor((win_w - box_w) / 2))
      end

      local f = floats[idx]
      local fbuf, fwin
      if f and vim.api.nvim_buf_is_valid(f.buf) and vim.api.nvim_win_is_valid(f.win) then
        fbuf, fwin = f.buf, f.win
        vim.bo[fbuf].modifiable = true
        vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
        vim.bo[fbuf].modifiable = false
        vim.api.nvim_win_set_config(fwin, {
          relative = "win",
          win = item.win,
          row = row,
          col = col,
          width = box_w,
          height = box_h,
          border = is_active and "double" or "rounded",
        })
      else
        fbuf = vim.api.nvim_create_buf(false, true)
        vim.bo[fbuf].buftype = "nofile"
        vim.bo[fbuf].bufhidden = "wipe"
        vim.bo[fbuf].filetype = "spotlight_badge"
        vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
        vim.bo[fbuf].modifiable = false

        fwin = vim.api.nvim_open_win(fbuf, false, {
          relative = "win",
          win = item.win,
          row = row,
          col = col,
          width = box_w,
          height = box_h,
          style = "minimal",
          border = is_active and "double" or "rounded",
          focusable = false,
          noautocmd = true,
          zindex = 250,
        })
        floats[idx] = { buf = fbuf, win = fwin }
      end

      local hl_norm = is_active and "SpotlightBadgeActive" or "SpotlightBadgeInactive"
      local hl_bord = is_active and "SpotlightBadgeActiveBorder" or "SpotlightBadgeInactiveBorder"
      vim.wo[fwin].winhighlight = string.format("Normal:%s,FloatBorder:%s", hl_norm, hl_bord)
    end
  end

  return floats
end

---Close all floating badges cleanly
---@param floats table<integer, {buf: integer, win: integer}>
function M.clear_badges(floats)
  if not floats then
    return
  end
  for _, f in pairs(floats) do
    if f.win and vim.api.nvim_win_is_valid(f.win) then
      pcall(vim.api.nvim_win_close, f.win, true)
    end
    if f.buf and vim.api.nvim_buf_is_valid(f.buf) then
      pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
    end
  end
end

return M
