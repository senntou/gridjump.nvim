# gridjump.nvim

A fast grid-based cursor jump plugin for Neovim, inspired by [hop.nvim](https://github.com/phaazon/hop.nvim) and [jumpcursor.vim](https://github.com/skanehira/jumpcursor.vim).

## How it works

Invoke `:GridJump` and the visible buffer is overlaid with index characters:

- **Columns** on the configured index rows (dim, waiting for row selection)
- **Rows** on the configured index columns (highlighted, prompt for row key)

Press a **row key** → that row is highlighted, column indices appear on it.  
Press a **column key** → cursor jumps to the intersection.

Press `<Esc>` at any point to cancel.

```
Before pressing anything:
  a │ some text here         ← row 'a' shown at index_cols position
  b │ another line           ← row 'b'
  c │ third line             ← row 'c'
    └─a──b──c──d──e──        ← col chars shown at index_rows position (dim)

After pressing 'b' (row selected):
  a │ (dim)
  b │ a b c d e f g h ...   ← col chars highlighted on the selected row
  c │ (dim)

Press 'c' → jumps to row b, column c
```

## Requirements

- Neovim 0.9+

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/gridjump.nvim",
  config = function()
    require("gridjump").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/gridjump.nvim",
  config = function()
    require("gridjump").setup()
  end,
}
```

## Usage

```
:GridJump
```

Or bind it to a key:

```lua
vim.keymap.set("n", "<leader>j", "<cmd>GridJump<cr>", { desc = "GridJump" })
```

## Configuration

Call `setup()` with any options you want to override. All fields are optional.

```lua
require("gridjump").setup({
  -- Rows at which column-index characters are displayed (phase 1, dim).
  -- Negative values count from the bottom: -1 = last visible row.
  index_rows = { 1 },

  -- Columns at which row-index characters are displayed.
  -- Negative values count from the right: -1 = last visible column.
  index_cols = { 1 },

  -- Highlight groups used for the overlay characters.
  -- Each value can be:
  --   string  → link to an existing highlight group (e.g. "DiagnosticInfo")
  --   table   → passed directly to nvim_set_hl (e.g. { fg = "#ff0000", bold = true })
  index_style = {
    highlight = "DiagnosticInfo",  -- active index (row phase 1, selected row/col phase 2)
    dim       = "Comment",         -- inactive index
  },

  -- Custom character order for index labels.
  -- Characters listed here are used first; any characters from the default
  -- sequence that are absent are appended after them.
  -- Default sequence: abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
  -- Example: "qwertyuiop" → index order becomes "qwertyuiopasdfghjklzxcvbnmABC..."
  index_chars = "",

  -- Assign an index to every N-th visible row/column.
  -- row_stride = 2 means only every other row gets a label.
  row_stride = 1,
  col_stride = 1,
})
```

## Examples

### Keyboard-layout-aware characters

```lua
require("gridjump").setup({
  index_chars = "qwertyuiopasdfghjklzxcvbnm",
})
```

### Show column indices on both the first and last visible rows

```lua
require("gridjump").setup({
  index_rows = { 1, -1 },
})
```

### Red overlay with bold text

```lua
require("gridjump").setup({
  index_style = {
    highlight = { fg = "#ff5555", bold = true },
    dim       = { fg = "#555555" },
  },
})
```

### Sparse labels for large files

```lua
require("gridjump").setup({
  row_stride = 3,
  col_stride = 4,
})
```

## License

MIT
