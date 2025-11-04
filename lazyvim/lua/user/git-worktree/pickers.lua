local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local themes = require("telescope.themes")

local M = {}

M.confirm_picker = function(title, on_confirm, on_cancel)
  local opts = themes.get_dropdown({
    prompt_title = title,
    layout_config = {
      width = 0.3,
      height = 0.15,
    },
  })

  pickers
    .new(opts, {
      finder = finders.new_table({
        results = { "No", "Yes" },
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)

          if selection and selection[1] == "Yes" then
            if on_confirm then
              on_confirm()
            end
          else
            if on_cancel then
              on_cancel()
            end
          end
        end)

        map("i", "<Esc>", function()
          actions.close(prompt_bufnr)
          if on_cancel then
            on_cancel()
          end
        end)

        return true
      end,
    })
    :find()
end

M.input_picker = function(prompt_title, default_text, on_submit)
  vim.ui.input({
    prompt = prompt_title,
    default = default_text or "",
  }, function(input)
    if input then
      on_submit(input)
    end
  end)
end

M.worktree_picker = function(on_switch, on_delete)
  local utils = require("user.git-worktree.utils")
  local worktrees = utils.get_worktree_list()

  if #worktrees == 0 then
    vim.notify("Нет доступных worktree", vim.log.levels.INFO)
    return
  end

  local opts = themes.get_dropdown({
    prompt_title = "Git Worktrees",
    layout_config = {
      width = 0.6,
      height = 0.4,
    },
  })

  pickers
    .new(opts, {
      finder = finders.new_table({
        results = worktrees,
        entry_maker = function(entry)
          local display = entry.branch or "(detached)"
          if entry.is_current then
            display = display .. " (current)"
          end
          display = display .. " - " .. entry.path

          return {
            value = entry,
            display = display,
            ordinal = entry.branch or entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if selection then
            actions.close(prompt_bufnr)
            if on_switch then
              on_switch(selection.value)
            end
          end
        end)

        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            actions.close(prompt_bufnr)
            if on_delete then
              on_delete(selection.value)
            end
          end
        end)

        return true
      end,
    })
    :find()
end

-- Universal branch picker with support for custom input
M.branch_picker = function(prompt_title, default_value, on_select)
  local utils = require("user.git-worktree.utils")
  local branches = utils.get_all_branches()

  local opts = themes.get_dropdown({
    prompt_title = prompt_title,
    default_text = default_value or "",
    layout_config = {
      width = 0.6,
      height = 0.4,
    },
  })

  pickers
    .new(opts, {
      finder = finders.new_table({
        results = branches,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local input_text = picker:_get_prompt()

          actions.close(prompt_bufnr)

          -- If there's a selection, use it; otherwise use input text
          local branch_name
          if selection then
            branch_name = selection[1]
          elseif input_text and input_text ~= "" then
            branch_name = input_text
          else
            vim.notify("Название ветки не может быть пустым", vim.log.levels.ERROR)
            return
          end

          if on_select then
            on_select(branch_name)
          end
        end)

        return true
      end,
    })
    :find()
end

return M

