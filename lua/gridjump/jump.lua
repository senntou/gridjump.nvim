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

local function manhattan(r1, c1, r2, c2)
  return math.abs(r1 - r2) + math.abs(c1 - c2)
end

-- Find the visible (row_i, col_i) of the nearest text character to (target_row_i, target_col_i).
-- row_i and col_i are 1-indexed within the visible window.
-- Returns (best_row_i, best_col_i); falls back to (target_row_i, 1) if buffer is empty.
local function find_nearest_text_pos(bufnr, view, target_row_i, target_col_i, dist_fn)
  dist_fn = dist_fn or manhattan
  local best_dist = math.huge
  local best_row_i = target_row_i
  local best_col_i = 1

  for row_i = 1, view.n_rows do
    local lnum_0 = view.first_line + row_i - 2
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum_0, lnum_0 + 1, false)[1] or ""
    local line_dw = vim.fn.strdisplaywidth(line)
    local max_col_i = math.max(0, line_dw - view.leftcol)
    if max_col_i > 0 then
      -- Nearest reachable column in this row to target_col_i
      local nearest_col = math.max(1, math.min(target_col_i, max_col_i))
      local d = dist_fn(target_row_i, target_col_i, row_i, nearest_col)
      if d < best_dist then
        best_dist = d
        best_row_i = row_i
        best_col_i = nearest_col
      end
    end
  end

  return best_row_i, best_col_i
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

  local target_line, target_byte
  if config.free_jump then
    local dist_fn = (type(config.distance_fn) == "function") and config.distance_fn or nil
    local nr, nc = find_nearest_text_pos(bufnr, view, row_visible, col_visible, dist_fn)
    target_line = view.first_line + nr - 1
    target_byte = visible_col_to_byte(view.winid, target_line, view.leftcol, nc)
  else
    target_line = view.first_line + row_visible - 1
    target_byte = visible_col_to_byte(view.winid, target_line, view.leftcol, col_visible)
  end

  vim.api.nvim_win_set_cursor(0, { target_line, target_byte })
  vim.cmd("redraw")
end

return M
