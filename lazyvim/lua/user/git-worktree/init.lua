local M = {}

M.setup = function(opts)
  local config = require("user.git-worktree.config")
  config.setup(opts)

  local commands = require("user.git-worktree.commands")
  commands.setup()
end

return M

