# 🔦 `spotlight.nvim`

**Ghostty-Inspired Visual Split Picker, 2D Buffer Exposé Grid, Split Zoom, and Unfocused Dimming for Neovim (`>= 0.10.0`).**

`spotlight.nvim` puts your active window and buffers in the spotlight—combining **spatial `h/j/k/l` navigation + instant home-row badges** across splits and a **2D visual Buffer Exposé card grid** with multi-buffer split layout composition.

---

## ✨ Features

1. **🎯 Visual Split & Window Picker (`:SpotlightPick` / `<leader>wf` / `<A-w>`)**
   - Renders high-contrast floating hint badges (`[a]`, `[s]`, `[d]`, `[f]`, ...) over every split and terminal pane in the current tabpage.
   - **Dual Selection**: Use **`h` / `j` / `k` / `l`** (and arrow keys) to move the glowing highlight frame spatially across splits + **`<CR>`** to pick, **OR** press the badge letter directly (`h/j/k/l` are excluded from badge letters so both work simultaneously without conflict).
   - Works seamlessly from both **Normal (`n`)** and **Terminal (`t`)** modes.
   - Action modes: **Jump** (`<CR>`), **Swap** (`S` or `<leader>ws`), **Close Split** (`x` or `<leader>wx`), and **Pull Buffer** (`p` or `<leader>wp`).

2. **🗂️ 2D Buffer Exposé Grid & Multi-Select Layout Composer (`:SpotlightBuffers` / `<leader>wb` / `<A-b>`)**
   - Displays open code and terminal buffers as a 2D grid of live preview cards.
   - **Tab Workspace Scoped by Default**: Shows buffers belonging to the active tab workspace (natively integrating with `buffer-buddy.nvim`), with an interactive tab bar at the top: press **`T`** to toggle **All Tabs** view (`<leader>wB`), or **`[` / `]`** to inspect other tabs.
   - **Multi-Buffer Selection (`<Tab>` / `<Space>`)**: Select 2, 3, or 4+ buffers (`[✓1]`, `[✓2]`, ...) and press `<CR>` (or `v` = vertical columns, `s` = horizontal rows, `g` = 2x2 grid, `m` = main + stack) to tile them immediately.

3. **🔍 Ghostty-Style Split Zoom (`:SpotlightZoom` / `<leader>wz` / `<C-w>z`)**
   - Lossless full-frame zoom of the active split (like Ghostty's `toggle_split_zoom`) with a `🔦 SPOTLIGHT ZOOM [1/N]` indicator badge and automatic layout restoration when switching windows.

4. **🌑 Unfocused Split Dimming & Golden-Ratio Auto-Resize (`:SpotlightDim` / `:SpotlightGolden`)**
   - Mirrors Ghostty's `unfocused-split-opacity` using per-window `winhighlight` (`<leader>wd`) and optional Golden-Ratio split sizing (`<leader>wg`) with sidebar protection.

---

## ⌨️ Default Keybindings

| Keybinding | Mode | Command / API | Description |
| :--- | :---: | :--- | :--- |
| **`<leader>wf`** / **`<A-w>`** | `n`, `t` | `:SpotlightPick` | **Visual Split Picker**: `h/j/k/l` + `<CR>` or `[a][s][d][f]` badge jump |
| **`<leader>wb`** / **`<A-b>`** | `n`, `t` | `:SpotlightBuffers tab` | **Buffer Exposé (Current Tab)**: 2D preview cards + multi-select layout composer |
| **`<leader>wB`** | `n`, `t` | `:SpotlightBuffers all` | **Buffer Exposé (All Tabs)**: Inspect & pick buffers across all tabs |
| **`<leader>wz`** / **`<C-w>z`** | `n`, `t` | `:SpotlightZoom` | **Split Zoom**: Maximize/restore active split (`toggle_split_zoom`) |
| **`<leader>ws`** | `n` | `:SpotlightPick swap` | **Swap Splits**: Pick a target split to swap with the active window |
| **`<leader>wx`** | `n` | `:SpotlightPick close` | **Close Split**: Pick a target split to close remotely |
| **`<leader>wp`** | `n` | `:SpotlightPick pull` | **Pull Buffer**: Pick another split and pull its buffer into active window |
| **`<leader>wd`** | `n` | `:SpotlightDim toggle` | **Toggle Dimming**: Toggle unfocused window dimming on/off |
| **`<leader>wg`** | `n` | `:SpotlightGolden toggle` | **Toggle Golden Ratio**: Toggle automatic golden-ratio split sizing |
| **`<leader>w=`** | `n` | `spotlight.equalize()` | **Equalize Splits**: Balance all non-fixed splits |
| **`<leader>wM`** | `n` | `:SpotlightHUD` | **Spotlight HUD**: Open interactive Spotlight Control Center |

---

## 📦 Installation (`lazy.nvim`)

```lua
{
  "pradhyu/spotlight.nvim",
  dir = vim.fn.expand("~/git/spotlight.nvim"),
  lazy = false,
  config = function()
    require("spotlight").setup()
  end,
}
```

See [SPEC.md](SPEC.md) for the complete architecture and configuration specification.
