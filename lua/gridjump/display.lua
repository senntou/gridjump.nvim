local M = {}

local ns_id = vim.api.nvim_create_namespace("gridjump")

local HL_HIGHLIGHT = "GridJumpHighlight"
local HL_DIM = "GridJumpDim"

local function apply_hl(dest, spec)
  if type(spec) == "string" then
    vim.api.nvim_set_hl(0, dest, { link = spec, default = false })
  elseif type(spec) == "table" then
    vim.api.nvim_set_hl(0, dest, vim.tbl_extend("force", { default = false }, spec))
  end
end

function M.setup_highlights(style)
  apply_hl(HL_HIGHLIGHT, style.highlight)
  apply_hl(HL_DIM, style.dim)
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, ns_id, 0, -1)
end

local function resolve_pos(pos, total)
  if pos < 0 then
    return total + pos + 1
  end
  return pos
end

function M.get_view()
  local winid = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()
  local first_line = view.topline
  local last_line = vim.fn.line("w$")
  local n_rows = last_line - first_line + 1
  local leftcol = view.leftcol

  local win_width = vim.api.nvim_win_get_width(winid)
  local textoff = vim.fn.getwininfo(winid)[1].textoff or 0
  local text_width = win_width - textoff

  return {
    first_line = first_line,
    last_line = last_line,
    n_rows = n_rows,
    leftcol = leftcol,
    text_width = text_width,
    winid = winid,
  }
end

local function place_char(bufnr, lnum_0, win_col, char, hl_group)
  if lnum_0 < 0 or lnum_0 >= vim.api.nvim_buf_line_count(bufnr) then
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum_0, 0, {
    virt_text = { { char, hl_group } },
    virt_text_win_col = win_col,
    priority = 200,
  })
end

-- selected_row_i: nil = phase 1, otherwise the 1-indexed visible row that was chosen.
--
-- Phase 1: row indices = highlight, col indices = dim
-- Phase 2: selected row index = highlight, others = dim; col indices on selected row = highlight
local function render(bufnr, view, config, chars_str, selected_row_i)
  local n_rows = view.n_rows
  local n_cols = view.text_width
  local row_stride = config.row_stride or 1
  local col_stride = config.col_stride or 1

  -- === Row index chars at index_cols positions ===
  local row_char_idx = 0
  for row_i = 1, n_rows do
    if (row_i - 1) % row_stride == 0 then
      row_char_idx = row_char_idx + 1
      local char = chars_str:sub(row_char_idx, row_char_idx)
      if char == "" then
        break
      end

      local lnum_0 = view.first_line + row_i - 2
      local hl
      if selected_row_i == nil then
        hl = HL_HIGHLIGHT
      elseif row_i == selected_row_i then
        hl = HL_HIGHLIGHT
      else
        hl = HL_DIM
      end

      for _, col_pos in ipairs(config.index_cols) do
        local col_i = resolve_pos(col_pos, n_cols)
        if col_i >= 1 and col_i <= n_cols then
          place_char(bufnr, lnum_0, col_i - 1, char, hl)
        end
      end
    end
  end

  -- === Col index chars ===
  -- Phase 1: dim on index_rows positions.
  -- Phase 2: highlight on selected row only, capped at the line's display width.
  local selected_lnum_0, selected_max_col_i
  if selected_row_i ~= nil then
    selected_lnum_0 = view.first_line + selected_row_i - 2
    local line = vim.api.nvim_buf_get_lines(bufnr, selected_lnum_0, selected_lnum_0 + 1, false)[1] or ""
    local line_dw = vim.fn.strdisplaywidth(line)
    selected_max_col_i = math.max(0, line_dw - view.leftcol)
  end

  local col_char_idx = 0
  for col_i = 1, (selected_max_col_i or n_cols) do
    if (col_i - 1) % col_stride == 0 then
      col_char_idx = col_char_idx + 1
      local char = chars_str:sub(col_char_idx, col_char_idx)
      if char == "" then
        break
      end

      if selected_row_i == nil then
        for _, row_pos in ipairs(config.index_rows) do
          local row_i = resolve_pos(row_pos, n_rows)
          if row_i >= 1 and row_i <= n_rows then
            local lnum_0 = view.first_line + row_i - 2
            place_char(bufnr, lnum_0, col_i - 1, char, HL_DIM)
          end
        end
      else
        place_char(bufnr, selected_lnum_0, col_i - 1, char, HL_HIGHLIGHT)
      end
    end
  end
end

function M.show(bufnr, config, chars_str)
  M.clear(bufnr)
  M.setup_highlights(config.index_style)
  local view = M.get_view()
  render(bufnr, view, config, chars_str, nil)
  vim.cmd("redraw")
  return view
end

function M.show_row_selected(bufnr, view, config, chars_str, selected_row_i)
  M.clear(bufnr)
  render(bufnr, view, config, chars_str, selected_row_i)
  vim.cmd("redraw")
end

return M
