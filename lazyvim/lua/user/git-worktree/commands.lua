local M = {}

M.setup = function()
  local core = require("user.git-worktree.core")

  vim.api.nvim_create_user_command("GitWorktreeCreate", function()
    core.create_worktree()
  end, { desc = "Create a new git worktree" })

  vim.api.nvim_create_user_command("GitWorktreeSwitch", function()
    core.switch_worktree()
  end, { desc = "Switch or delete git worktree" })
end

return M

