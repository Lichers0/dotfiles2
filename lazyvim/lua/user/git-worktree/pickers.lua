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
        results = { "Yes", "No" },
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

return M

