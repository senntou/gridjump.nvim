local M = {}

-- index_style values can be either:
--   string  → linked to that highlight group (e.g. "DiagnosticInfo")
--   table   → passed directly to nvim_set_hl (e.g. { fg = "#00ffff", bold = true })
M.defaults = {
  index_rows = { 1 },
  index_cols = { 1 },
  index_style = {
    highlight = "DiagnosticInfo", -- active indices (usually cyan/blue)
    dim       = "Comment",        -- inactive indices
  },
  index_chars = "",
  row_stride = 1, -- assign index every N visible rows
  col_stride = 1, -- assign index every N visible columns
}

function M.merge(user_config)
  local config = vim.deepcopy(M.defaults)
  if not user_config then
    return config
  end
  for k, v in pairs(user_config) do
    if k == "index_style" and type(v) == "table" then
      config.index_style = vim.tbl_extend("force", config.index_style, v)
    else
      config[k] = v
    end
  end
  return config
end

return M
