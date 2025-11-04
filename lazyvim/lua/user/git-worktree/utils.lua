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

M.validate_branch_name = function(name, base_branch)
  if name == "" then
    return false, "Название ветки не может быть пустым"
  end

  if base_branch and name == base_branch then
    return false, "Название новой ветки должно отличаться от базовой"
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

M.get_main_worktree_path = function()
  local worktrees = M.get_worktree_list()

  -- Сначала ищем master, потом main
  for _, wt in ipairs(worktrees) do
    if wt.branch == "master" then
      return wt.path
    end
  end

  for _, wt in ipairs(worktrees) do
    if wt.branch == "main" then
      return wt.path
    end
  end

  -- Если не нашли master или main, возвращаем первый worktree (обычно основной)
  if #worktrees > 0 then
    return worktrees[1].path
  end

  -- Возвращаем корень git как fallback
  return M.get_git_root()
end

-- Get all branches (local and remote)
M.get_all_branches = function()
  local result = vim.fn.system("git branch -a --format='%(refname:short)' 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local branches = {}
  local seen = {}

  for line in result:gmatch("[^\n]+") do
    -- Remove remotes/origin/ prefix for remote branches
    local branch = line:gsub("^remotes/origin/", "")
    -- Skip HEAD pointer
    if branch ~= "HEAD" and not seen[branch] then
      table.insert(branches, branch)
      seen[branch] = true
    end
  end

  return branches
end

-- Check if branch exists (local or remote)
M.branch_exists = function(branch_name)
  if not branch_name or branch_name == "" then
    return false
  end

  -- Check local branch
  local local_result = vim.fn.system(
    string.format("git show-ref --verify --quiet refs/heads/%s 2>/dev/null", branch_name)
  )
  if vim.v.shell_error == 0 then
    return true
  end

  -- Check remote branch
  local remote_result = vim.fn.system(
    string.format("git show-ref --verify --quiet refs/remotes/origin/%s 2>/dev/null", branch_name)
  )
  return vim.v.shell_error == 0
end

-- Check if master or main branch exists in worktree list
M.has_main_branch_worktree = function()
  local worktrees = M.get_worktree_list()

  for _, wt in ipairs(worktrees) do
    if wt.branch == "master" then
      return true, "master"
    end
  end

  for _, wt in ipairs(worktrees) do
    if wt.branch == "main" then
      return true, "main"
    end
  end

  return false, nil
end

-- Get main branch name (master or main)
M.get_main_branch_name = function()
  local has_main, branch_name = M.has_main_branch_worktree()
  return branch_name
end

-- Check if path is a symbolic link
M.is_symlink = function(path)
  if not path or path == "" then
    return false
  end

  local result = vim.fn.system(string.format("test -L '%s' && echo 'yes' || echo 'no'", path))
  return result:match("yes") ~= nil
end

-- Check gitignore for specific folders (in specified worktree or current if not specified)
M.check_gitignore_entries = function(folders, worktree_path)
  local target_path = worktree_path or vim.fn.getcwd()

  local gitignore_path = target_path .. "/.gitignore"
  local file = io.open(gitignore_path, "r")

  if not file then
    -- .gitignore doesn't exist - create notification and return all as missing
    vim.notify(".gitignore не найден в " .. target_path .. ", будет создан при добавлении записей", vim.log.levels.INFO)
    return folders -- Return all as missing if .gitignore doesn't exist
  end

  local content = file:read("*all")
  file:close()

  local missing = {}
  for _, folder in ipairs(folders) do
    -- Check for exact match of folder name (with or without leading slash)
    local pattern = folder:gsub("([%.%-%+])", "%%%1") -- Escape special chars
    if not content:match("\n" .. pattern .. "\n") and
       not content:match("\n" .. pattern .. "$") and
       not content:match("^" .. pattern .. "\n") and
       not content:match("^" .. pattern .. "$") and
       not content:match("\n/" .. pattern .. "\n") and
       not content:match("\n/" .. pattern .. "$") then
      table.insert(missing, folder)
    end
  end

  return missing
end

-- Add folders to .gitignore (in the specified worktree or current if not specified)
M.add_to_gitignore = function(folders, worktree_path, auto_stage)
  local target_path = worktree_path or vim.fn.getcwd()

  local gitignore_path = target_path .. "/.gitignore"

  -- Check if .gitignore already exists and read its content
  local existing_content = ""
  local existing_file = io.open(gitignore_path, "r")
  if existing_file then
    existing_content = existing_file:read("*all")
    existing_file:close()
  end

  -- Open file for appending
  local file = io.open(gitignore_path, "a")
  if not file then
    return false, "Не удалось открыть .gitignore для записи"
  end

  -- Add newline if file doesn't end with one
  if existing_content ~= "" and not existing_content:match("\n$") then
    file:write("\n")
  end

  -- Add comment
  file:write("\n# Auto-added by git-worktree plugin\n")

  for _, folder in ipairs(folders) do
    file:write(folder .. "\n")
  end

  file:close()

  -- Auto stage the .gitignore file if requested
  if auto_stage then
    local stage_cmd = string.format("cd '%s' && git add .gitignore 2>&1", target_path)
    local result = vim.fn.system(stage_cmd)
    if vim.v.shell_error ~= 0 then
      return false, "Ошибка добавления .gitignore в индекс: " .. result
    end
    vim.notify(".gitignore добавлен в git индекс", vim.log.levels.INFO)
  end

  return true, nil
end

-- Find folder in main worktree
M.find_folder_in_main_worktree = function(folder_name)
  local main_path = M.get_main_worktree_path()
  if not main_path then
    return nil
  end

  local folder_path = main_path .. "/" .. folder_name
  local result = vim.fn.system(string.format("test -d '%s' && echo 'exists' || echo 'missing'", folder_path))

  if result:match("exists") then
    return folder_path
  end

  return nil
end

-- Create symbolic link
M.create_symlink = function(source_path, target_path)
  -- Check if source exists
  local source_check = vim.fn.system(string.format("test -e '%s' && echo 'exists' || echo 'missing'", source_path))
  if not source_check:match("exists") then
    return false, "Исходная папка не существует: " .. source_path
  end

  -- Check if target already exists
  local target_check = vim.fn.system(string.format("test -e '%s' && echo 'exists' || echo 'missing'", target_path))
  if target_check:match("exists") then
    if M.is_symlink(target_path) then
      return true, nil -- Already a symlink, skip
    else
      return false, "Путь уже существует и не является симлинком: " .. target_path
    end
  end

  -- Create symlink
  local cmd = string.format("ln -s '%s' '%s' 2>&1", source_path, target_path)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, result
  end

  return true, nil
end

M.create_worktree = function(branch_name, base_branch, is_new_branch)
  local config = require("user.git-worktree.config")
  local main_path = M.get_main_worktree_path()
  if not main_path then
    return false, "Не удалось определить путь основного worktree"
  end

  local path = main_path .. "/" .. config.options.worktree_path .. branch_name

  local cmd
  if is_new_branch then
    -- Create worktree with new branch
    cmd = string.format("git worktree add '%s' -b '%s' '%s' 2>&1", path, branch_name, base_branch)
  else
    -- Create worktree with existing branch
    cmd = string.format("git worktree add '%s' '%s' 2>&1", path, branch_name)
  end

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

-- Check if folder is tracked (committed) in master/main branch
M.is_folder_tracked_in_main = function(folder_name)
  local main_branch = M.get_main_branch_name()
  if not main_branch then
    return false -- If no main branch, treat as untracked
  end

  -- Try to list tree for this folder in main branch
  local cmd = string.format("git ls-tree %s '%s' 2>/dev/null", main_branch, folder_name)
  local result = vim.fn.system(cmd)

  -- If output is not empty and command succeeded, folder exists in git tree
  return vim.v.shell_error == 0 and result:match("%S") ~= nil
end

-- Setup symlinks for worktree (main function)
M.setup_worktree_symlinks = function(new_worktree_path)
  local config = require("user.git-worktree.config")
  local pickers = require("user.git-worktree.pickers")

  local folders_to_link = config.options.symlink_folders or {}
  if #folders_to_link == 0 then
    return -- Nothing to do
  end

  -- Filter out tracked folders (committed in master/main)
  local untracked_folders = {}
  for _, folder in ipairs(folders_to_link) do
    if not M.is_folder_tracked_in_main(folder) then
      table.insert(untracked_folders, folder)
    end
  end

  -- If all folders are tracked, nothing to do
  if #untracked_folders == 0 then
    return
  end

  -- Use only untracked folders for symlink creation
  folders_to_link = untracked_folders

  -- Statistics
  local stats = {
    created = 0,
    skipped = 0,
    errors = {},
  }

  -- Step 1: Check gitignore in the NEW worktree
  if config.options.auto_add_to_gitignore then
    local missing_in_gitignore = M.check_gitignore_entries(folders_to_link, new_worktree_path)

    if #missing_in_gitignore > 0 then
      local folders_list = table.concat(missing_in_gitignore, ", ")

      if config.options.skip_gitignore_confirmation then
        -- Skip confirmation dialog and add directly
        local success, err = M.add_to_gitignore(missing_in_gitignore, new_worktree_path, config.options.auto_stage_gitignore)
        if success then
          local message = "Папки автоматически добавлены в .gitignore: " .. folders_list
          if config.options.auto_stage_gitignore then
            message = message .. " и проиндексированы"
          end
          vim.notify(message, vim.log.levels.INFO)
        else
          vim.notify("Ошибка добавления в .gitignore: " .. err, vim.log.levels.WARN)
        end
      else
        -- Show confirmation dialog
        local message = string.format(config.options.confirm_messages.add_to_gitignore, folders_list)

        -- Show notification first
        vim.notify("Обнаружены папки для добавления в .gitignore: " .. folders_list, vim.log.levels.WARN)

        -- Use vim.defer_fn to ensure the picker shows up properly
        vim.defer_fn(function()
          pickers.confirm_picker(message, function()
            -- Add with configurable auto-staging
            local success, err = M.add_to_gitignore(missing_in_gitignore, new_worktree_path, config.options.auto_stage_gitignore)
            if success then
              local msg = "Папки добавлены в .gitignore: " .. folders_list
              if config.options.auto_stage_gitignore then
                msg = msg .. " и проиндексированы"
              end
              vim.notify(msg, vim.log.levels.INFO)
            else
              vim.notify("Ошибка добавления в .gitignore: " .. err, vim.log.levels.WARN)
            end
          end, function()
            vim.notify("Пропущено добавление в .gitignore", vim.log.levels.INFO)
          end)
        end, 100) -- Small delay to ensure notification is shown first
      end
    end
  end

  -- Step 2: Create symlinks for each folder
  for _, folder in ipairs(folders_to_link) do
    local target_path = new_worktree_path .. "/" .. folder

    -- Check if folder already exists in new worktree
    local target_check = vim.fn.system(string.format("test -e '%s' && echo 'exists' || echo 'missing'", target_path))

    if target_check:match("exists") then
      if M.is_symlink(target_path) then
        -- Already a symlink, skip silently
        stats.skipped = stats.skipped + 1
      else
        -- Exists but not a symlink - warn and skip
        local msg = string.format("Папка '%s' уже существует в worktree, симлинк не создан", folder)
        vim.notify(msg, vim.log.levels.WARN)
        stats.skipped = stats.skipped + 1
        table.insert(stats.errors, msg)
      end
    else
      -- Folder doesn't exist in new worktree - try to create symlink
      local source_path = M.find_folder_in_main_worktree(folder)

      if not source_path then
        -- Folder doesn't exist in main worktree
        if config.options.create_missing_folders then
          local main_path = M.get_main_worktree_path()
          if main_path then
            source_path = main_path .. "/" .. folder
            local mkdir_cmd = string.format("mkdir -p '%s' 2>&1", source_path)
            local mkdir_result = vim.fn.system(mkdir_cmd)

            if vim.v.shell_error == 0 then
              vim.notify(string.format("Создана папка '%s' в master/main", folder), vim.log.levels.INFO)
            else
              local msg = string.format("Ошибка создания папки '%s': %s", folder, mkdir_result)
              vim.notify(msg, vim.log.levels.ERROR)
              stats.skipped = stats.skipped + 1
              table.insert(stats.errors, msg)
              goto continue
            end
          else
            local msg = string.format("Не удалось определить путь к master/main для создания '%s'", folder)
            vim.notify(msg, vim.log.levels.ERROR)
            stats.skipped = stats.skipped + 1
            table.insert(stats.errors, msg)
            goto continue
          end
        else
          local msg = string.format("Папка '%s' не найдена в master/main, симлинк не создан", folder)
          vim.notify(msg, vim.log.levels.INFO)
          stats.skipped = stats.skipped + 1
          goto continue
        end
      end

      -- Create symlink
      local success, err = M.create_symlink(source_path, target_path)
      if success then
        vim.notify(string.format("Создан симлинк для '%s'", folder), vim.log.levels.INFO)
        stats.created = stats.created + 1
      else
        local msg = string.format("Ошибка создания симлинка для '%s': %s", folder, err or "неизвестная ошибка")
        vim.notify(msg, vim.log.levels.ERROR)
        stats.skipped = stats.skipped + 1
        table.insert(stats.errors, msg)
      end
    end

    ::continue::
  end

  -- Step 3: Show summary
  local summary_parts = {}
  if stats.created > 0 then
    table.insert(summary_parts, string.format("Создано симлинков: %d", stats.created))
  end
  if stats.skipped > 0 then
    table.insert(summary_parts, string.format("Пропущено: %d", stats.skipped))
  end

  if #summary_parts > 0 then
    vim.notify("Настройка симлинков завершена. " .. table.concat(summary_parts, ", "), vim.log.levels.INFO)
  end
end

return M

