local M = {}

---@class SpotlightConfig
M.defaults = {
  -- 1. Visual Split & Window Picker (Overlay Badges + h/j/k/l Navigation)
  picker = {
    directional_keys = true,             -- Use h/j/k/l (and arrows) to move highlight across splits + <CR> to pick
    keys = "asdfgqwertzxcvbyuiopnm",     -- Hint labels (excludes h/j/k/l so both work simultaneously!)
    position = "center",                 -- "center" | "top_right" | "top_left"
    badge_size = "large",                -- "compact" (1-line) | "large" (3-line box with buffer name)
    include_floating = false,            -- Include focusable floating windows
    include_sidebars = true,             -- Allow picking Neo-tree / Trouble / TOC sidebars
    auto_terminal_insert = true,         -- Automatically enter insert mode when jumping to a terminal split
  },

  -- 2. 2D Buffer Exposé Grid & Multi-Select Layout Composer
  grid = {
    default_scope = "tab",               -- "tab" (current tab workspace only) | "all" (all tabs)
    cross_tab_action = "jump_tab",       -- "jump_tab" (switch to that tab) | "pull" (open in current tab)
    max_columns = 3,                     -- Max cards per row in the Exposé grid
    preview_lines = 7,                   -- Lines of syntax-highlighted preview per card
    include_terminals = true,            -- Show running terminal buffers in the grid
    default_multi_layout = "auto",       -- "auto" | "vsplit" | "hsplit" | "grid" | "main_left"
    border = "rounded",
  },

  -- 3. Ghostty-Style Split Zoom
  zoom = {
    mode = "native",                     -- "native" (winrestcmd maximize) | "float" (fullscreen spotlight overlay)
    float_scale = 0.94,                  -- Scale when mode == "float"
    show_badge = true,                   -- Show "🔦 SPOTLIGHT ZOOM [1/N]" indicator badge
    auto_unzoom_on_leave = true,         -- Restore splits automatically when switching windows
  },

  -- 4. Unfocused Split Dimming (Ghostty `unfocused-split-opacity`)
  dim = {
    enabled = true,
    dim_terminal = false,                -- Keep live terminal buffers bright or dim them too
    mute_diagnostics = false,            -- Optionally mute diagnostic virtual text in unfocused splits
    excluded_filetypes = {
      "neo-tree",
      "NvimTree",
      "Trouble",
      "qf",
      "snacks_notif",
      "lazy",
      "mason",
      "spotlight_grid",
      "spotlight_hud",
      "spotlight_badge",
      "bufferbuddy_hud",
    },
  },

  -- 5. Smart Golden-Ratio Auto-Resizing
  resize = {
    golden_ratio = false,                -- Opt-in automatic golden-ratio split sizing on WinEnter
    focused_width_ratio = 0.62,          -- Target width % for focused window
    focused_height_ratio = 0.62,         -- Target height % for focused window
    step_size = 5,                       -- Step size for directional resize helpers
    excluded_buftypes = {
      "nofile",
      "quickfix",
      "prompt",
      "help",
      "acwrite",
    },
    excluded_filetypes = {
      "neo-tree",
      "NvimTree",
      "Trouble",
      "qf",
      "help",
      "supermarkdown_toc",
      "bufferbuddy_hud",
      "spotlight_hud",
      "spotlight_grid",
      "spotlight_badge",
      "dap-repl",
      "dapui_watches",
      "dapui_stacks",
      "dapui_breakpoints",
      "dapui_scopes",
      "dapui_console",
      "neotest-summary",
      "neotest-output-panel",
      "overseer",
      "aerial",
      "Outline",
    },
  },

  -- 6. Default Keymaps
  keymaps = {
    enabled = true,
  },
}

---@type SpotlightConfig
M.options = vim.deepcopy(M.defaults)

---Define Spotlight highlight groups
function M.setup_highlights()
  local set_hl = vim.api.nvim_set_hl
  -- Candidate / Active badge in Split Picker (when selected via h/j/k/l)
  set_hl(0, "SpotlightBadgeActive", { fg = "#11111b", bg = "#f9e2af", bold = true, default = true })
  set_hl(0, "SpotlightBadgeActiveBorder", { fg = "#f9e2af", bg = "#1e1e2e", bold = true, default = true })
  -- Other split badges
  set_hl(0, "SpotlightBadgeInactive", { fg = "#cdd6f4", bg = "#313244", bold = true, default = true })
  set_hl(0, "SpotlightBadgeInactiveBorder", { fg = "#89b4fa", bg = "#1e1e2e", default = true })
  set_hl(0, "SpotlightBadgeKey", { fg = "#11111b", bg = "#89b4fa", bold = true, default = true })
  set_hl(0, "SpotlightBadgeTitle", { fg = "#cdd6f4", bg = "#1e1e2e", italic = true, default = true })

  -- Exposé Grid highlights
  set_hl(0, "SpotlightGridNormal", { link = "NormalFloat", default = true })
  set_hl(0, "SpotlightGridBorder", { fg = "#89b4fa", bold = true, default = true })
  set_hl(0, "SpotlightGridTitle", { fg = "#11111b", bg = "#89b4fa", bold = true, default = true })
  set_hl(0, "SpotlightCardActive", { fg = "#f9e2af", bold = true, default = true })
  set_hl(0, "SpotlightCardSelected", { fg = "#a6e3a1", bold = true, default = true })
  set_hl(0, "SpotlightCardHeader", { fg = "#89dceb", bold = true, default = true })
  set_hl(0, "SpotlightCardMeta", { fg = "#6c7086", italic = true, default = true })
  set_hl(0, "SpotlightTabActive", { fg = "#11111b", bg = "#a6e3a1", bold = true, default = true })
  set_hl(0, "SpotlightTabInactive", { fg = "#a6adc8", bg = "#313244", default = true })

  -- Zoom badge
  set_hl(0, "SpotlightZoomBadge", { fg = "#11111b", bg = "#f38ba8", bold = true, default = true })

  -- Dimmed window highlights (Ghostty unfocused-split-opacity style)
  set_hl(0, "SpotlightDimNormal", { fg = "#585b70", default = true })
  set_hl(0, "SpotlightDimLineNr", { fg = "#45475a", default = true })
  set_hl(0, "SpotlightDimWinSeparator", { fg = "#313244", default = true })
end

---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.setup_highlights()
end

return M
