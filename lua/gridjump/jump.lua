local M = {}

local display = require("gridjump.display")
local chars_mod = require("gridjump.chars")

local function visible_col_to_byte(winid, lnum_1idx, leftcol, col_i)
  local abs_vcol = leftcol + col_i
  local byte_1idx = vim.fn.virtcol2col(winid, lnum_1idx, abs_vcol)
  if byte_1idx <= 0 then
    return 0
  end
  return byte_1idx - 1
end

function M.start(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local chars_str = chars_mod.build(config.index_chars)
  local row_stride = config.row_stride or 1
  local col_stride = config.col_stride or 1

  -- Phase 1: show all indices, wait for row key
  local view = display.show(bufnr, config, chars_str)

  local ok, row_key = pcall(vim.fn.getcharstr)
  if not ok or row_key == "\27" then
    display.clear(bufnr)
    vim.cmd("redraw")
    return
  end

  local row_char_idx = chars_mod.find(chars_str, row_key)
  -- Convert char index → actual visible row position (1-indexed)
  local row_visible = row_char_idx and (row_char_idx - 1) * row_stride + 1
  if not row_visible or row_visible > view.n_rows then
    display.clear(bufnr)
    vim.cmd("redraw")
    return
  end

  -- Phase 2: dim other rows, show col indices on the selected row only
  display.show_row_selected(bufnr, view, config, chars_str, row_visible)

  local ok2, col_key = pcall(vim.fn.getcharstr)
  display.clear(bufnr)

  if not ok2 or col_key == "\27" then
    vim.cmd("redraw")
    return
  end

  local col_char_idx = chars_mod.find(chars_str, col_key)
  -- Convert char index → actual visible column position (1-indexed)
  local col_visible = col_char_idx and (col_char_idx - 1) * col_stride + 1
  if not col_visible or col_visible > view.text_width then
    vim.cmd("redraw")
    return
  end

  local target_line = view.first_line + row_visible - 1
  local target_byte = visible_col_to_byte(view.winid, target_line, view.leftcol, col_visible)

  vim.api.nvim_win_set_cursor(0, { target_line, target_byte })
  vim.cmd("redraw")
end

return M
