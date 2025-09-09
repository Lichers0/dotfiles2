local M = {}

local utils = require("user.git-worktree.utils")
local pickers = require("user.git-worktree.pickers")
local config = require("user.git-worktree.config")

M.create_worktree = function()
  if not utils.is_git_repo() then
    vim.notify(
      "Текущая директория не является git репозиторием",
      vim.log.levels.ERROR
    )
    return
  end

  local current_branch = utils.get_current_branch()
  local prompt = string.format("Название новой ветки (на основе %s): ", current_branch)

  pickers.input_picker(prompt, "", function(branch_name)
    local valid, err = utils.validate_branch_name(branch_name)
    if not valid then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    vim.notify("Создание worktree...", vim.log.levels.INFO)

    local success, result = utils.create_worktree(branch_name, current_branch)
    if not success then
      vim.notify("Ошибка создания worktree: " .. result, vim.log.levels.ERROR)
      return
    end

    vim.notify("Worktree создан: " .. result, vim.log.levels.INFO)

    pickers.confirm_picker(config.options.confirm_messages.switch_after_create, function()
      utils.switch_worktree(result)
      vim.notify("Переключено на worktree: " .. branch_name, vim.log.levels.INFO)
    end, function()
      vim.notify("Остаёмся в текущем worktree", vim.log.levels.INFO)
    end)
  end)
end

M.switch_worktree = function()
  if not utils.is_git_repo() then
    vim.notify(
      "Текущая директория не является git репозиторием",
      vim.log.levels.ERROR
    )
    return
  end

  pickers.worktree_picker(function(worktree)
    if worktree.is_current then
      vim.notify("Уже находимся в этом worktree", vim.log.levels.INFO)
      return
    end

    utils.switch_worktree(worktree.path)
    vim.notify("Переключено на worktree: " .. (worktree.branch or worktree.path), vim.log.levels.INFO)
  end, function(worktree)
    if worktree.is_current then
      vim.notify("Нельзя удалить текущий worktree", vim.log.levels.ERROR)
      return
    end

    pickers.confirm_picker(config.options.confirm_messages.delete_worktree, function()
      local success, err = utils.remove_worktree(worktree.path)
      if not success then
        vim.notify("Ошибка удаления worktree: " .. err, vim.log.levels.ERROR)
        return
      end

      vim.notify("Worktree удалён из git", vim.log.levels.INFO)

      pickers.confirm_picker(config.options.confirm_messages.delete_folder, function()
        local del_success, del_err = utils.delete_folder(worktree.path)
        if del_success then
          vim.notify("Папка worktree удалена", vim.log.levels.INFO)
        else
          vim.notify("Ошибка удаления папки: " .. del_err, vim.log.levels.ERROR)
        end
      end, function()
        vim.notify("Папка worktree сохранена", vim.log.levels.INFO)
      end)
    end, function()
      vim.notify("Удаление отменено", vim.log.levels.INFO)
    end)
  end)
end

return M

