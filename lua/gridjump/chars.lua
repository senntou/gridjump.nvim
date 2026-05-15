local M = {}

local DEFAULT_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

-- Build final char sequence: custom prefix + remaining default chars not in custom
function M.build(custom)
  if not custom or custom == "" then
    return DEFAULT_CHARS
  end

  local used = {}
  for i = 1, #custom do
    used[custom:sub(i, i)] = true
  end

  local result = custom
  for i = 1, #DEFAULT_CHARS do
    local c = DEFAULT_CHARS:sub(i, i)
    if not used[c] then
      result = result .. c
    end
  end

  return result
end

-- Return 1-indexed position of key in chars_str, or nil
function M.find(chars_str, key)
  for i = 1, #chars_str do
    if chars_str:sub(i, i) == key then
      return i
    end
  end
  return nil
end

return M
