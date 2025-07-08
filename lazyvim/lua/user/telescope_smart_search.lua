-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values
-- local actions = require('telescope.actions')
-- local action_state = require('telescope.actions.state')
local entry_maker = require("telescope.make_entry")

local M = {}

M.smart_search = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()
  pickers
    .new(opts, {
      prompt_title = "Multi grep",
      finder = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
          return nil
        end

        local pieces = vim.split(prompt, "  ")
        local args = { "rg" }

        if pieces[1] then
          table.insert(args, "-e")
          table.insert(args, pieces[1])
        end

        if pieces[2] then
          table.insert(args, "-g")
          table.insert(args, pieces[2])
        end

        return vim.tbl_flatten({
          args,
          { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
        })
      end, entry_maker.gen_from_vimgrep(opts)),
      debounce = 100,
      cwd = opts.cwd,
      sorter = sorters.empty(),
      previewer = conf.grep_previewer(opts),
      -- attach_mappings = function(_, map)
      --   actions.select_default:replace(function()
      --     local selection = action_state.get_selected_entry()
      --     actions.close()
      --     vim.cmd("edit " .. selection.path)
      --   end)
      --   return true
      -- end,
    })
    :find()
end

return M
