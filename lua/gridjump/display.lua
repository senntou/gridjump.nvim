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
--   Overlap rule: row index wins (skip col placement at those cells)
-- Phase 2: selected row index = highlight, others = dim; col indices on selected row = highlight
--   Overlap rule on selected row: col index wins (skip row placement at those cells)
--
-- Each (lnum_0, win_col) receives at most one extmark — the higher-priority char.
-- Relying on extmark priority to overwrite at the same position is unreliable in Neovim.
local function render(bufnr, view, config, chars_str, selected_row_i)
  local n_rows = view.n_rows
  local n_cols = view.text_width
  local row_stride = config.row_stride or 1
  local col_stride = config.col_stride or 1
  local fill_gaps = config.fill_stride_gaps == true

  -- Phase 2: resolve selected row info up front so the row loop can skip col positions.
  local selected_lnum_0, selected_max_col_i
  if selected_row_i ~= nil then
    selected_lnum_0 = view.first_line + selected_row_i - 2
    local line = vim.api.nvim_buf_get_lines(bufnr, selected_lnum_0, selected_lnum_0 + 1, false)[1] or ""
    local line_dw = vim.fn.strdisplaywidth(line)
    selected_max_col_i = math.max(0, line_dw - view.leftcol)
  end

  -- Phase 2: win_cols on selected_lnum_0 that will carry a col index char.
  -- Row index chars must NOT be placed here (col has priority on selected row).
  local col_indexed_wincols = {}
  if selected_row_i ~= nil then
    for col_i = 1, (selected_max_col_i or n_cols) do
      if (col_i - 1) % col_stride == 0 then
        col_indexed_wincols[col_i - 1] = true
      end
    end
  end

  -- Track win_cols per lnum_0 where row index chars were actually placed.
  -- Phase 1 uses this to skip col placement at those cells (row has priority).
  local row_placed = {}

  -- === Row index chars at index_cols positions ===
  local row_char_idx = 0
  for row_i = 1, n_rows do
    local lnum_0 = view.first_line + row_i - 2
    if (row_i - 1) % row_stride == 0 then
      row_char_idx = row_char_idx + 1
      local char = chars_str:sub(row_char_idx, row_char_idx)
      if char == "" then break end

      local hl = (selected_row_i == nil or row_i == selected_row_i) and HL_HIGHLIGHT or HL_DIM

      for _, col_pos in ipairs(config.index_cols) do
        local col_i = resolve_pos(col_pos, n_cols)
        if col_i >= 1 and col_i <= n_cols then
          local win_col = col_i - 1
          -- Phase 2: skip on selected row where col index takes priority
          if lnum_0 == selected_lnum_0 and col_indexed_wincols[win_col] then
            -- col index will be placed here; don't place row index
          else
            place_char(bufnr, lnum_0, win_col, char, hl)
            if not row_placed[lnum_0] then row_placed[lnum_0] = {} end
            row_placed[lnum_0][win_col] = true
          end
        end
      end
    elseif fill_gaps then
      for _, col_pos in ipairs(config.index_cols) do
        local col_i = resolve_pos(col_pos, n_cols)
        if col_i >= 1 and col_i <= n_cols then
          local win_col = col_i - 1
          if not (lnum_0 == selected_lnum_0 and col_indexed_wincols[win_col]) then
            place_char(bufnr, lnum_0, win_col, " ", HL_DIM)
          end
        end
      end
    end
  end

  -- === Col index chars ===
  local col_char_idx = 0
  for col_i = 1, (selected_max_col_i or n_cols) do
    local win_col = col_i - 1
    local is_indexed_col = (col_i - 1) % col_stride == 0

    if is_indexed_col then
      col_char_idx = col_char_idx + 1
      local char = chars_str:sub(col_char_idx, col_char_idx)
      if char == "" then break end

      if selected_row_i == nil then
        -- Phase 1: row index has priority at overlap cells
        for _, row_pos in ipairs(config.index_rows) do
          local row_i = resolve_pos(row_pos, n_rows)
          if row_i >= 1 and row_i <= n_rows then
            local lnum_0 = view.first_line + row_i - 2
            if not (row_placed[lnum_0] and row_placed[lnum_0][win_col]) then
              place_char(bufnr, lnum_0, win_col, char, HL_DIM)
            end
          end
        end
      else
        -- Phase 2: col index takes priority; row index was already skipped here
        place_char(bufnr, selected_lnum_0, win_col, char, HL_HIGHLIGHT)
      end
    elseif fill_gaps then
      if selected_row_i == nil then
        for _, row_pos in ipairs(config.index_rows) do
          local row_i = resolve_pos(row_pos, n_rows)
          if row_i >= 1 and row_i <= n_rows then
            local lnum_0 = view.first_line + row_i - 2
            if not (row_placed[lnum_0] and row_placed[lnum_0][win_col]) then
              place_char(bufnr, lnum_0, win_col, " ", HL_DIM)
            end
          end
        end
      else
        -- Phase 2: fill gap on selected row (skip if row index is already there)
        if not (row_placed[selected_lnum_0] and row_placed[selected_lnum_0][win_col]) then
          place_char(bufnr, selected_lnum_0, win_col, " ", HL_DIM)
        end
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
