local M = {}

local config_mod = require("gridjump.config")
local jump = require("gridjump.jump")

local _config = config_mod.defaults

function M.setup(user_config)
  _config = config_mod.merge(user_config)
end

function M.jump()
  jump.start(_config)
end

return M
