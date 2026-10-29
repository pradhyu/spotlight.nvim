if vim.g.loaded_spotlight_nvim then
  return
end
vim.g.loaded_spotlight_nvim = 1

vim.api.nvim_create_user_command("SpotlightPick", function(opts)
  local action = opts.args ~= "" and opts.args or "jump"
  require("spotlight").pick_window({ action = action })
end, {
  nargs = "?",
  complete = function()
    return { "jump", "swap", "close", "pull" }
  end,
  desc = "Spotlight: Visual Split & Window Picker (h/j/k/l + Badges)",
})

vim.api.nvim_create_user_command("SpotlightBuffers", function(opts)
  local arg = opts.args ~= "" and opts.args or "tab"
  if arg == "all" or arg == "tab" then
    require("spotlight").open_grid({ scope = arg })
  elseif arg == "code" or arg == "term" then
    require("spotlight").open_grid({ filter = arg })
  else
    require("spotlight").open_grid()
  end
end, {
  nargs = "?",
  complete = function()
    return { "tab", "all", "code", "term" }
  end,
  desc = "Spotlight: 2D Buffer Exposé Grid & Multi-Select Layout Composer",
})

vim.api.nvim_create_user_command("SpotlightZoom", function(opts)
  local mode = opts.args ~= "" and opts.args or nil
  require("spotlight").toggle_zoom(mode)
end, {
  nargs = "?",
  complete = function()
    return { "native", "float" }
  end,
  desc = "Spotlight: Toggle Ghostty-style Split Zoom",
})

vim.api.nvim_create_user_command("SpotlightLayout", function(opts)
  local layout = opts.args ~= "" and opts.args or "auto"
  local cards = require("spotlight").get_cards({ scope = "tab" })
  local bufs = vim.tbl_map(function(c)
    return c.buf
  end, cards)
  require("spotlight").compose_layout(bufs, layout)
end, {
  nargs = "?",
  complete = function()
    return { "vsplit", "hsplit", "grid", "main_left", "main_top" }
  end,
  desc = "Spotlight: Arrange current tab buffers into a split layout",
})

vim.api.nvim_create_user_command("SpotlightDim", function(opts)
  local state = opts.args ~= "" and opts.args or "toggle"
  local enabled = require("spotlight").toggle_dim(state)
  vim.notify("[Spotlight] Unfocused Split Dimming: " .. (enabled and "ON" or "OFF"), vim.log.levels.INFO)
end, {
  nargs = "?",
  complete = function()
    return { "on", "off", "toggle" }
  end,
  desc = "Spotlight: Control unfocused split dimming",
})

vim.api.nvim_create_user_command("SpotlightGolden", function(opts)
  local state = opts.args ~= "" and opts.args or "toggle"
  local enabled = require("spotlight").toggle_golden(state)
  vim.notify("[Spotlight] Golden-Ratio Auto-Resize: " .. (enabled and "ON" or "OFF"), vim.log.levels.INFO)
end, {
  nargs = "?",
  complete = function()
    return { "on", "off", "toggle" }
  end,
  desc = "Spotlight: Control automatic golden-ratio split resizing",
})

vim.api.nvim_create_user_command("SpotlightHUD", function()
  require("spotlight").open_hud()
end, {
  desc = "Spotlight: Open Interactive Control Center",
})
