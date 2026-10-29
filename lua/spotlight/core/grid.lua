local config = require("spotlight.config")

local M = {}

local IGNORED_FTS = {
  ["spotlight_grid"] = true,
  ["spotlight_hud"] = true,
  ["spotlight_badge"] = true,
  ["bufferbuddy_hud"] = true,
  ["bufferbuddy_scratch_picker"] = true,
  ["neo-tree"] = true,
  ["NvimTree"] = true,
  ["lazy"] = true,
  ["mason"] = true,
  ["snacks_notif"] = true,
  ["notify"] = true,
  ["noice"] = true,
}

local FT_ICONS = {
  lua = "󰢱",
  markdown = "󰍔",
  python = "󰌠",
  javascript = "󰌞",
  typescript = "󰛦",
  json = "󰘦",
  sh = "",
  bash = "",
  zsh = "",
  html = "󰌝",
  css = "󰌜",
  rust = "󱘗",
  go = "󰟓",
  c = "󰙱",
  cpp = "󰙲",
}

---Get a short icon for a buffer
---@param buf integer
---@return string
local function get_buf_icon(buf)
  if vim.bo[buf].buftype == "terminal" then
    return ""
  end
  local ft = vim.bo[buf].filetype or ""
  return FT_ICONS[ft] or "󰈙"
end

---Sanitize and truncate a single line to a fixed display width
---@param str string
---@param width integer
---@return string
local function fit_width(str, width)
  str = (str or ""):gsub("\t", "  "):gsub("[\r\n]", "")
  local dw = vim.fn.strdisplaywidth(str)
  if dw > width then
    -- Safely slice character by character using strcharpart
    local out = vim.fn.strcharpart(str, 0, math.max(1, width - 1))
    while vim.fn.strdisplaywidth(out) > width - 1 and #out > 0 do
      out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
    end
    str = out .. "…"
    dw = vim.fn.strdisplaywidth(str)
  end
  if dw < width then
    str = str .. string.rep(" ", width - dw)
  end
  return str
end

---Get tab display name (integrates with buffer-buddy.nvim if available)
---@param tab_handle integer
---@return string
function M.get_tab_name(tab_handle)
  if not vim.api.nvim_tabpage_is_valid(tab_handle) then
    return "Tab"
  end
  local tab_num = vim.api.nvim_tabpage_get_number(tab_handle)
  local ok, bb_tabs = pcall(require, "buffer_buddy.core.tabs")
  if ok and bb_tabs and type(bb_tabs.get_tab_name) == "function" then
    local custom = bb_tabs.get_tab_name(tab_handle)
    if custom and custom ~= "" then
      return string.format("%d:%s", tab_num, custom)
    end
  end
  local win = vim.api.nvim_tabpage_get_win(tab_handle)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local short = name ~= "" and vim.fn.fnamemodify(name, ":t") or "Scratch"
  if vim.bo[buf].buftype == "terminal" then
    short = "term:" .. (name:match(":([^:/]+)$") or "sh")
  end
  return string.format("%d:%s", tab_num, short)
end

---@class SpotlightCardItem
---@field buf integer
---@field key string
---@field title string
---@field icon string
---@field is_term boolean
---@field modified boolean
---@field tab_handle integer
---@field tab_num integer
---@field win_in_tab integer|nil
---@field preview string[]

---Collect buffers for the given scope ("tab" or "all") and target tabpage
---@param opts? { scope?: "tab"|"all", tab?: integer, filter?: "all"|"code"|"term", query?: string }
---@return SpotlightCardItem[]
function M.get_cards(opts)
  opts = opts or {}
  local grid_cfg = config.options.grid or {}
  local scope = opts.scope or grid_cfg.default_scope or "tab"
  local target_tab = opts.tab or vim.api.nvim_get_current_tabpage()
  if not vim.api.nvim_tabpage_is_valid(target_tab) then
    target_tab = vim.api.nvim_get_current_tabpage()
  end
  local filter_kind = opts.filter or "all"
  local query = (opts.query or ""):lower()

  local keys = (config.options.picker and config.options.picker.keys) or "asdfgqwertzxcvbyuiopnm"
  local preview_count = grid_cfg.preview_lines or 6

  -- Map buffers visible in windows across tabs
  local buf_to_tab = {}
  local buf_to_win = {}
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(t)) do
      if vim.api.nvim_win_is_valid(w) then
        local b = vim.api.nvim_win_get_buf(w)
        if t == target_tab or not buf_to_tab[b] then
          buf_to_tab[b] = t
          buf_to_win[b] = w
        end
      end
    end
  end

  -- Determine candidate buffer set for "tab" scope
  local tab_buf_set = {}
  if scope == "tab" then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(target_tab)) do
      if vim.api.nvim_win_is_valid(w) then
        tab_buf_set[vim.api.nvim_win_get_buf(w)] = true
      end
    end
    local ok, bb_tabs = pcall(require, "buffer_buddy.core.tabs")
    if ok and bb_tabs and type(bb_tabs.get_tab_buffers) == "function" then
      for _, b in ipairs(bb_tabs.get_tab_buffers(target_tab)) do
        tab_buf_set[b] = true
      end
    elseif target_tab == vim.api.nvim_get_current_tabpage() then
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
          tab_buf_set[b] = true
        end
      end
    end
  end

  local cards = {}
  local key_idx = 1

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) then
      local ft = vim.bo[b].filetype or ""
      local bt = vim.bo[b].buftype or ""
      local name = vim.api.nvim_buf_get_name(b)
      local is_term = (bt == "terminal" or name:match("^term://") ~= nil)
      local is_listed = vim.bo[b].buflisted or is_term or (buf_to_win[b] ~= nil)

      local include = is_listed and not IGNORED_FTS[ft]
      if is_term and grid_cfg.include_terminals == false then
        include = false
      end
      if bt == "nofile" or bt == "prompt" or bt == "quickfix" then
        include = false
      end
      if scope == "tab" and not tab_buf_set[b] then
        include = false
      end
      if filter_kind == "code" and is_term then
        include = false
      elseif filter_kind == "term" and not is_term then
        include = false
      end

      if include then
        local title
        if is_term then
          local cmd = name:match(":([^:/]+)$") or "shell"
          title = "term:" .. cmd
        elseif name == "" then
          title = string.format("[Scratch #%d]", b)
        else
          title = vim.fn.fnamemodify(name, ":t")
        end

        if query == "" or title:lower():find(query, 1, true) or ft:lower():find(query, 1, true) then
          local total_lines = vim.api.nvim_buf_line_count(b)
          local start_line = 0
          if is_term then
            -- For terminal buffers, find the last non-empty line
            local all_lines = vim.api.nvim_buf_get_lines(b, math.max(0, total_lines - 60), total_lines, false)
            local last_non_empty = #all_lines
            for i = #all_lines, 1, -1 do
              if all_lines[i]:match("%S") then
                last_non_empty = i
                break
              end
            end
            local base = math.max(0, total_lines - 60)
            local end_l = base + last_non_empty
            start_line = math.max(0, end_l - preview_count)
          else
            local mark = vim.api.nvim_buf_get_mark(b, '"')
            local center = (mark and mark[1] > 0) and mark[1] or 1
            start_line = math.max(0, math.min(center - 2, math.max(0, total_lines - preview_count)))
          end

          local raw_lines = vim.api.nvim_buf_get_lines(b, start_line, start_line + preview_count, false)
          local preview = {}
          for i = 1, preview_count do
            local lnum = start_line + i
            local txt = raw_lines[i] or "~"
            table.insert(preview, string.format("%3d │ %s", lnum <= total_lines and lnum or 0, txt))
          end

          local key = keys:sub(key_idx, key_idx)
          if key == "" then
            key = tostring(key_idx)
          end
          key_idx = key_idx + 1

          local t_handle = buf_to_tab[b] or target_tab
          local t_num = vim.api.nvim_tabpage_is_valid(t_handle) and vim.api.nvim_tabpage_get_number(t_handle) or 1

          table.insert(cards, {
            buf = b,
            key = key,
            title = title,
            icon = get_buf_icon(b),
            is_term = is_term,
            modified = vim.bo[b].modified,
            tab_handle = t_handle,
            tab_num = t_num,
            win_in_tab = buf_to_win[b],
            preview = preview,
          })
        end
      end
    end
  end

  return cards
end

---Arrange a list of buffer numbers into a split layout in the current tabpage
---@param bufnrs integer[]
---@param layout? "auto"|"vsplit"|"hsplit"|"grid"|"main_left"|"main_top"
function M.compose_layout(bufnrs, layout)
  local valid = {}
  for _, b in ipairs(bufnrs or {}) do
    if vim.api.nvim_buf_is_valid(b) then
      table.insert(valid, b)
    end
  end
  if #valid == 0 then
    return
  end

  layout = layout or (config.options.grid and config.options.grid.default_multi_layout) or "auto"
  if layout == "auto" then
    if #valid == 1 then
      layout = "single"
    elseif #valid == 2 then
      layout = "vsplit"
    elseif #valid == 3 then
      layout = "main_left"
    else
      layout = "grid"
    end
  end

  if layout == "single" or #valid == 1 then
    local b = valid[1]
    -- Check if buffer is already open in a window of current tab
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == b then
        vim.api.nvim_set_current_win(w)
        return
      end
    end
    vim.api.nvim_win_set_buf(0, b)
    return
  end

  -- Clear non-sidebar splits in current tab to build clean layout
  local cur_win = vim.api.nvim_get_current_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= cur_win and vim.api.nvim_win_is_valid(w) then
      local b = vim.api.nvim_win_get_buf(w)
      local ft = vim.bo[b].filetype or ""
      if not vim.wo[w].winfixwidth and not IGNORED_FTS[ft] then
        pcall(vim.api.nvim_win_close, w, false)
      end
    end
  end

  vim.api.nvim_win_set_buf(0, valid[1])
  local main_win = vim.api.nvim_get_current_win()

  if layout == "vsplit" then
    for i = 2, #valid do
      vim.cmd("rightbelow vsplit")
      vim.api.nvim_win_set_buf(0, valid[i])
    end
    vim.cmd("wincmd =")
  elseif layout == "hsplit" then
    for i = 2, #valid do
      vim.cmd("rightbelow split")
      vim.api.nvim_win_set_buf(0, valid[i])
    end
    vim.cmd("wincmd =")
  elseif layout == "main_left" then
    vim.cmd("rightbelow vsplit")
    vim.api.nvim_win_set_buf(0, valid[2])
    for i = 3, #valid do
      vim.cmd("rightbelow split")
      vim.api.nvim_win_set_buf(0, valid[i])
    end
    if vim.api.nvim_win_is_valid(main_win) then
      local total_w = vim.o.columns
      pcall(vim.api.nvim_win_set_width, main_win, math.floor(total_w * 0.58))
    end
  elseif layout == "main_top" then
    vim.cmd("rightbelow split")
    vim.api.nvim_win_set_buf(0, valid[2])
    for i = 3, #valid do
      vim.cmd("rightbelow vsplit")
      vim.api.nvim_win_set_buf(0, valid[i])
    end
  elseif layout == "grid" then
    -- 2x2 or 2xN balanced grid
    vim.cmd("rightbelow vsplit")
    local right_top = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(right_top, valid[2])

    if valid[3] then
      vim.api.nvim_set_current_win(main_win)
      vim.cmd("rightbelow split")
      vim.api.nvim_win_set_buf(0, valid[3])
    end
    if valid[4] then
      vim.api.nvim_set_current_win(right_top)
      vim.cmd("rightbelow split")
      vim.api.nvim_win_set_buf(0, valid[4])
    end
    for i = 5, #valid do
      vim.cmd("rightbelow vsplit")
      vim.api.nvim_win_set_buf(0, valid[i])
    end
    vim.cmd("wincmd =")
  end

  if vim.api.nvim_win_is_valid(main_win) then
    vim.api.nvim_set_current_win(main_win)
  end
end

---Open the interactive 2D Buffer Exposé Grid & Multi-Select Layout Composer
---@param opts? { scope?: "tab"|"all", filter?: "all"|"code"|"term" }
function M.open_grid(opts)
  opts = opts or {}
  local mode = vim.api.nvim_get_mode().mode
  if mode == "t" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  end

  local grid_cfg = config.options.grid or {}
  local state = {
    scope = opts.scope or grid_cfg.default_scope or "tab",
    target_tab = vim.api.nvim_get_current_tabpage(),
    filter = opts.filter or "all",
    query = "",
    active_idx = 1,
    selected = {}, -- ordered list of selected buffer numbers
    selected_rank = {}, -- buf -> selection index (1, 2, 3...)
    cards = {},
  }

  local total_w = math.min(vim.o.columns - 4, math.max(76, math.floor(vim.o.columns * 0.90)))
  local total_h = math.min(vim.o.lines - 4, math.max(20, math.floor(vim.o.lines * 0.84)))
  local row = math.max(1, math.floor((vim.o.lines - total_h) / 2) - 1)
  local col = math.max(1, math.floor((vim.o.columns - total_w) / 2))

  local gbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[gbuf].buftype = "nofile"
  vim.bo[gbuf].bufhidden = "wipe"
  vim.bo[gbuf].filetype = "spotlight_grid"

  local gwin = vim.api.nvim_open_win(gbuf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = total_w,
    height = total_h,
    style = "minimal",
    border = grid_cfg.border or "rounded",
    title = " 🔦 Spotlight Buffer Exposé & Layout Composer ",
    title_pos = "center",
    zindex = 200,
  })
  vim.wo[gwin].winhighlight = "Normal:SpotlightGridNormal,FloatBorder:SpotlightGridBorder,FloatTitle:SpotlightGridTitle"
  vim.wo[gwin].cursorline = false

  local ns = vim.api.nvim_create_namespace("spotlight_grid_ns")

  local function rebuild_rank()
    state.selected_rank = {}
    for i, b in ipairs(state.selected) do
      state.selected_rank[b] = i
    end
  end

  local function toggle_select_buf(buf)
    local r = state.selected_rank[buf]
    if r then
      table.remove(state.selected, r)
    else
      table.insert(state.selected, buf)
    end
    rebuild_rank()
  end

  local function render()
    if not vim.api.nvim_buf_is_valid(gbuf) then
      return
    end
    state.cards = M.get_cards({
      scope = state.scope,
      tab = state.target_tab,
      filter = state.filter,
      query = state.query,
    })
    if state.active_idx > #state.cards then
      state.active_idx = math.max(1, #state.cards)
    end

    local lines = {}
    local highlights = {}

    -- 1. Top Workspace Tab Bar & Filter Status
    local tabs = vim.api.nvim_list_tabpages()
    local tab_parts = { " Tabs: " }
    for _, t in ipairs(tabs) do
      local lbl = M.get_tab_name(t)
      if state.scope == "tab" and t == state.target_tab then
        table.insert(tab_parts, string.format("[ ★ %s ]", lbl))
      else
        table.insert(tab_parts, string.format("[ %s ]", lbl))
      end
    end
    if state.scope == "all" then
      table.insert(tab_parts, " [ 🌐 ALL TABS * ]")
    else
      table.insert(tab_parts, " [ 🌐 All (T) ]")
    end

    local filter_str = string.format(
      "  │  Filter(f): %s%s  │  Selected: %d",
      state.filter:upper(),
      state.query ~= "" and (" /" .. state.query) or "",
      #state.selected
    )
    table.insert(lines, fit_width(table.concat(tab_parts, " ") .. filter_str, total_w))
    table.insert(highlights, { 0, 0, -1, "SpotlightCardHeader" })
    table.insert(lines, string.rep("─", total_w))
    table.insert(highlights, { 1, 0, -1, "Comment" })

    -- 2. Render 2D Card Grid
    local num_cards = #state.cards
    local cols = math.min(grid_cfg.max_columns or 3, math.max(1, math.floor(total_w / 28)))
    if num_cards > 0 and num_cards < cols then
      cols = num_cards
    end
    local card_w = math.floor((total_w - (cols + 1)) / cols)
    local inner_w = math.max(10, card_w - 2)
    local prev_lines = grid_cfg.preview_lines or 6

    if num_cards == 0 then
      table.insert(lines, "")
      table.insert(lines, fit_width("   No buffers match current scope/filter. Press [T] for All Tabs or [f] to change filter.", total_w))
      table.insert(lines, "")
    else
      local num_rows = math.ceil(num_cards / cols)
      for r = 1, num_rows do
        local row_cards = {}
        for c = 1, cols do
          local idx = (r - 1) * cols + c
          row_cards[c] = state.cards[idx]
        end

        -- Top border of cards in row r
        local top_parts = {}
        for c = 1, cols do
          local card = row_cards[c]
          local idx = (r - 1) * cols + c
          if card then
            local is_act = (idx == state.active_idx)
            local sel_rank = state.selected_rank[card.buf]
            local mod_mark = card.modified and " ●" or ""
            local tab_tag = (state.scope == "all") and string.format(" [T%d]", card.tab_num) or ""
            local sel_tag = sel_rank and string.format(" [✓%d]", sel_rank) or ""
            local head = string.format(" [%s] %s %s%s%s%s ", card.key, card.icon, card.title, mod_mark, tab_tag, sel_tag)
            head = fit_width(head, inner_w)
            if is_act then
              table.insert(top_parts, "╔" .. head:gsub(" ", "═") .. "╗")
            elseif sel_rank then
              table.insert(top_parts, "┏" .. head:gsub(" ", "━") .. "┓")
            else
              table.insert(top_parts, "╭" .. head:gsub(" ", "─") .. "╮")
            end
          else
            table.insert(top_parts, string.rep(" ", card_w))
          end
        end
        local top_line_idx = #lines
        table.insert(lines, " " .. table.concat(top_parts, " "))
        for c = 1, cols do
          local card = row_cards[c]
          local idx = (r - 1) * cols + c
          if card then
            local hl = (idx == state.active_idx) and "SpotlightCardActive"
              or (state.selected_rank[card.buf] and "SpotlightCardSelected" or "SpotlightCardHeader")
            table.insert(highlights, { top_line_idx, 0, -1, hl })
          end
        end

        -- Preview lines inside each card
        for p = 1, prev_lines do
          local body_parts = {}
          for c = 1, cols do
            local card = row_cards[c]
            local idx = (r - 1) * cols + c
            if card then
              local is_act = (idx == state.active_idx)
              local side = is_act and "║" or "│"
              local content = fit_width(card.preview[p] or "", inner_w)
              table.insert(body_parts, side .. content .. side)
            else
              table.insert(body_parts, string.rep(" ", card_w))
            end
          end
          table.insert(lines, " " .. table.concat(body_parts, " "))
        end

        -- Bottom border of cards in row r
        local bot_parts = {}
        for c = 1, cols do
          local card = row_cards[c]
          local idx = (r - 1) * cols + c
          if card then
            local is_act = (idx == state.active_idx)
            local sel_rank = state.selected_rank[card.buf]
            if is_act then
              table.insert(bot_parts, "╚" .. string.rep("═", inner_w) .. "╝")
            elseif sel_rank then
              table.insert(bot_parts, "┗" .. string.rep("━", inner_w) .. "┛")
            else
              table.insert(bot_parts, "╰" .. string.rep("─", inner_w) .. "╯")
            end
          else
            table.insert(bot_parts, string.rep(" ", card_w))
          end
        end
        local bot_line_idx = #lines
        table.insert(lines, " " .. table.concat(bot_parts, " "))
        table.insert(highlights, { bot_line_idx, 0, -1, "Comment" })
      end
    end

    -- 3. Footer Controls
    while #lines < total_h - 3 do
      table.insert(lines, "")
    end
    table.insert(lines, string.rep("─", total_w))
    table.insert(highlights, { #lines - 1, 0, -1, "Comment" })
    table.insert(
      lines,
      fit_width(" [h/j/k/l] Navigate Cards + [<CR>] Open   [<Tab>/<Space>] Multi-Select   [a/s/d/f...] Instant Pick", total_w)
    )
    table.insert(highlights, { #lines - 1, 0, -1, "SpotlightCardHeader" })
    table.insert(
      lines,
      fit_width(" [T] Tab/All Scope  [[/]] Switch Tab  Layout: [v] VSplit  [s] HSplit  [g] 2x2 Grid  [m] Main+Stack  [x] Close", total_w)
    )
    table.insert(highlights, { #lines - 1, 0, -1, "Comment" })

    vim.bo[gbuf].modifiable = true
    vim.api.nvim_buf_set_lines(gbuf, 0, -1, false, lines)
    vim.bo[gbuf].modifiable = false

    vim.api.nvim_buf_clear_namespace(gbuf, ns, 0, -1)
    for _, h in ipairs(highlights) do
      pcall(vim.api.nvim_buf_add_highlight, gbuf, ns, h[4], h[1], h[2], h[3])
    end

    return cols
  end

  local cols = render() or 3

  local function close_grid()
    if vim.api.nvim_win_is_valid(gwin) then
      pcall(vim.api.nvim_win_close, gwin, true)
    end
    if vim.api.nvim_buf_is_valid(gbuf) then
      pcall(vim.api.nvim_buf_delete, gbuf, { force = true })
    end
  end

  local function activate_card_or_selection(card, layout_override, force_pull)
    close_grid()
    if #state.selected > 0 then
      M.compose_layout(state.selected, layout_override or "auto")
      return
    end
    if not card or not vim.api.nvim_buf_is_valid(card.buf) then
      return
    end

    if layout_override and layout_override ~= "auto" then
      local cur_buf = vim.api.nvim_get_current_buf()
      if cur_buf ~= card.buf then
        M.compose_layout({ cur_buf, card.buf }, layout_override)
      else
        M.compose_layout({ card.buf }, "single")
      end
      return
    end

    local cur_tab = vim.api.nvim_get_current_tabpage()
    if not force_pull and state.scope == "all" and card.tab_handle ~= cur_tab and grid_cfg.cross_tab_action ~= "pull" then
      if vim.api.nvim_tabpage_is_valid(card.tab_handle) then
        vim.api.nvim_set_current_tabpage(card.tab_handle)
        if card.win_in_tab and vim.api.nvim_win_is_valid(card.win_in_tab) then
          vim.api.nvim_set_current_win(card.win_in_tab)
          return
        end
      end
    end

    -- If buffer is visible in a split of current tab, jump to that split
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == card.buf then
        vim.api.nvim_set_current_win(w)
        if vim.bo[card.buf].buftype == "terminal" then
          vim.cmd("startinsert")
        end
        return
      end
    end

    vim.api.nvim_win_set_buf(0, card.buf)
    if vim.bo[card.buf].buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end

  -- Interactive event loop for rapid 1-key / h/j/k/l navigation
  while true do
    vim.cmd("redraw")
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or ch == "\27" or ch == "\3" or ch == "q" then
      close_grid()
      break
    end

    local num = #state.cards
    if ch == "h" or ch == vim.keycode("<Left>") then
      if num > 0 then
        state.active_idx = ((state.active_idx - 2) % num) + 1
        cols = render() or cols
      end
    elseif ch == "l" or ch == vim.keycode("<Right>") then
      if num > 0 then
        state.active_idx = (state.active_idx % num) + 1
        cols = render() or cols
      end
    elseif ch == "j" or ch == vim.keycode("<Down>") then
      if num > 0 then
        state.active_idx = math.min(num, state.active_idx + cols)
        cols = render() or cols
      end
    elseif ch == "k" or ch == vim.keycode("<Up>") then
      if num > 0 then
        state.active_idx = math.max(1, state.active_idx - cols)
        cols = render() or cols
      end
    elseif ch == "\t" or ch == " " then
      local card = state.cards[state.active_idx]
      if card then
        toggle_select_buf(card.buf)
        state.active_idx = (state.active_idx % math.max(1, num)) + 1
        cols = render() or cols
      end
    elseif ch == "\r" or ch == "\n" then
      activate_card_or_selection(state.cards[state.active_idx], "auto", false)
      break
    elseif ch == "T" then
      state.scope = (state.scope == "tab") and "all" or "tab"
      state.active_idx = 1
      cols = render() or cols
    elseif ch == "[" or ch == "]" then
      local tabs = vim.api.nvim_list_tabpages()
      if #tabs > 1 then
        state.scope = "tab"
        local cur_i = 1
        for i, t in ipairs(tabs) do
          if t == state.target_tab then
            cur_i = i
            break
          end
        end
        if ch == "]" then
          cur_i = (cur_i % #tabs) + 1
        else
          cur_i = ((cur_i - 2) % #tabs) + 1
        end
        state.target_tab = tabs[cur_i]
        state.active_idx = 1
        cols = render() or cols
      end
    elseif ch == "v" and #state.selected > 0 then
      activate_card_or_selection(state.cards[state.active_idx], "vsplit", true)
      break
    elseif ch == "s" and #state.selected > 0 then
      activate_card_or_selection(state.cards[state.active_idx], "hsplit", true)
      break
    elseif ch == "g" and #state.selected > 0 then
      activate_card_or_selection(state.cards[state.active_idx], "grid", true)
      break
    elseif ch == "m" and #state.selected > 0 then
      activate_card_or_selection(state.cards[state.active_idx], "main_left", true)
      break
    elseif ch == "X" or (ch == "x" and #state.selected > 0) then
      local to_close = #state.selected > 0 and vim.deepcopy(state.selected)
        or (state.cards[state.active_idx] and { state.cards[state.active_idx].buf } or {})
      for _, b in ipairs(to_close) do
        if vim.api.nvim_buf_is_valid(b) and not vim.bo[b].modified then
          pcall(vim.api.nvim_buf_delete, b, { force = false })
        end
      end
      state.selected = {}
      rebuild_rank()
      cols = render() or cols
    elseif ch == "/" then
      vim.ui.input({ prompt = "Spotlight Filter: ", default = state.query }, function(input)
        if input ~= nil then
          state.query = input
          state.active_idx = 1
        end
      end)
      cols = render() or cols
    else
      -- Check if ch matches a card's badge key (lowercase = open/jump, uppercase = pull into current tab)
      local lower_ch = ch:lower()
      local matched = nil
      for _, card in ipairs(state.cards) do
        if card.key == lower_ch then
          matched = card
          break
        end
      end
      if matched then
        local force_pull = (ch ~= lower_ch)
        activate_card_or_selection(matched, "auto", force_pull)
        break
      end
    end
  end
end

return M
