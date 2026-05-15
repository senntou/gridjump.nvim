if vim.g.loaded_gridjump then
  return
end
vim.g.loaded_gridjump = true

vim.api.nvim_create_user_command("GridJump", function()
  require("gridjump").jump()
end, { desc = "Jump to a grid coordinate by pressing row then column key" })
