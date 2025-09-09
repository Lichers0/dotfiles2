local M = {}

M.is_git_repo = function()
  local result = vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null")
  return vim.v.shell_error == 0
end

M.get_current_branch = function()
  local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  return branch
end

M.get_worktree_list = function()
  local result = vim.fn.system("git worktree list --porcelain 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local worktrees = {}
  local current_worktree = {}

  for line in result:gmatch("[^\n]+") do
    if line:match("^worktree ") then
      if current_worktree.path then
        table.insert(worktrees, current_worktree)
      end
      current_worktree = { path = line:match("^worktree (.+)") }
    elseif line:match("^HEAD ") then
      current_worktree.commit = line:match("^HEAD (.+)")
    elseif line:match("^branch ") then
      current_worktree.branch = line:match("^branch refs/heads/(.+)")
    elseif line:match("^detached$") then
      current_worktree.detached = true
    elseif line == "" then
      if current_worktree.path then
        table.insert(worktrees, current_worktree)
        current_worktree = {}
      end
    end
  end

  if current_worktree.path then
    table.insert(worktrees, current_worktree)
  end

  local cwd = vim.fn.getcwd()
  for _, wt in ipairs(worktrees) do
    wt.is_current = wt.path == cwd
  end

  return worktrees
end

M.validate_branch_name = function(name)
  if name == "" then
    return false, "Название ветки не может быть пустым"
  end

  if name:match("[%s~%^:?*%[\\]") then
    return false, "Название ветки содержит недопустимые символы"
  end

  local existing = M.get_worktree_list()
  for _, wt in ipairs(existing) do
    if wt.branch == name then
      return false, "Worktree с такой веткой уже существует"
    end
  end

  return true, nil
end

M.get_git_root = function()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return git_root
end

M.create_worktree = function(branch_name, base_branch)
  local config = require("user.git-worktree.config")
  local git_root = M.get_git_root()
  if not git_root then
    return false, "Не удалось определить корень git репозитория"
  end

  local path = git_root .. "/" .. config.options.worktree_path .. branch_name

  local cmd = string.format("git worktree add '%s' -b '%s' '%s' 2>&1", path, branch_name, base_branch)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, result
  end

  return true, path
end

M.switch_worktree = function(path)
  vim.cmd("cd " .. path)
  vim.cmd("edit .")
  return true
end

M.remove_worktree = function(path)
  local cmd = string.format("git worktree remove '%s' 2>&1", path)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, result
  end

  return true, nil
end

M.delete_folder = function(path)
  local cmd = string.format("rm -rf '%s' 2>&1", path)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, result
  end

  return true, nil
end

return M

