local M = {}

M.options = {
  worktree_path = "worktrees/",
  auto_switch = true,
  auto_delete_folder = false,
  confirm_messages = {
    switch_after_create = "Переключиться на новую ветку?",
    delete_worktree = "Удалить worktree?",
    delete_folder = "Удалить папку worktree?",
  },
}

M.setup = function(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M