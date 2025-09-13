local M = {}

local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")

local storage = require("terminal-history.storage")
local config = require("terminal-history.config")
local core = require("terminal-history.core")

-- Format command entry for display with better layout
local function format_entry(entry)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 8 }, -- Time
      { remaining = true }, -- Command
    },
  })

  local timestamp = os.date(config.options.ui.date_format, entry.timestamp)
  local cmd = entry.command:gsub("\n", " ↵ ")

  return displayer({
    { timestamp, "TelescopeResultsNumber" },
    { cmd, "TelescopeResultsIdentifier" },
  })
end

-- Create previewer for command output
local function command_previewer()
  return previewers.new_buffer_previewer({
    title = "Command Output",
    define_preview = function(self, entry, status)
      -- Store wrap state in previewer instance
      if self.wrap == nil then
        self.wrap = false -- Default to wrap disabled
      end
      local output_lines = {}

      -- Add command info header
      table.insert(output_lines, "=== Command Output ===")
      table.insert(output_lines, "")

      -- Handle multi-line commands
      if entry.value.command:find("\n") then
        table.insert(output_lines, "Command (multi-line):")
        local cmd_lines = vim.split(entry.value.command, '\n', { plain = true })
        for _, cmd_line in ipairs(cmd_lines) do
          table.insert(output_lines, "  " .. cmd_line)
        end
      else
        table.insert(output_lines, "Command: " .. entry.value.command)
      end

      table.insert(output_lines, "")
      table.insert(output_lines, "Time: " .. os.date("%Y-%m-%d %H:%M:%S", entry.value.timestamp))

      if entry.value.duration then
        table.insert(output_lines, string.format("Duration: %.2fs", entry.value.duration))
      end

      if entry.value.cwd then
        table.insert(output_lines, "Directory: " .. entry.value.cwd)
      end

      table.insert(output_lines, "")
      table.insert(output_lines, string.rep("-", 60))
      table.insert(output_lines, "")

      -- Add command output
      if entry.value.output and entry.value.output ~= "" then
        -- Handle string output (split by lines)
        if type(entry.value.output) == "string" then
          -- Use vim.split to properly handle all lines including empty ones
          local lines = vim.split(entry.value.output, '\n', { plain = true })
          for _, line in ipairs(lines) do
            table.insert(output_lines, line)
          end
        -- Handle table output
        elseif type(entry.value.output) == "table" then
          for _, line in ipairs(entry.value.output) do
            table.insert(output_lines, line)
          end
        end
      else
        table.insert(output_lines, "(No output captured)")
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, output_lines)

      -- Set buffer options
      vim.api.nvim_set_option_value("filetype", "sh", { buf = self.state.bufnr })
      vim.api.nvim_set_option_value("modifiable", false, { buf = self.state.bufnr })

      -- Apply wrap setting to preview window
      vim.schedule(function()
        if self.state.winid and vim.api.nvim_win_is_valid(self.state.winid) then
          vim.api.nvim_set_option_value("wrap", self.wrap, { win = self.state.winid })
        end
      end)
    end,
  })
end

-- Copy output to new buffer
local function copy_output_to_buffer(entry, focus)
  -- Create new buffer
  local buf = vim.api.nvim_create_buf(true, false)

  -- Prepare content
  local lines = {}
  table.insert(lines, "-- Terminal History Output --")
  table.insert(lines, "-- Command: " .. entry.command:gsub("\n", " ↵ "))
  table.insert(lines, "-- Time: " .. os.date("%Y-%m-%d %H:%M:%S", entry.timestamp))
  if entry.duration then
    table.insert(lines, string.format("-- Duration: %.2fs", entry.duration))
  end
  if entry.cwd then
    table.insert(lines, "-- Directory: " .. entry.cwd)
  end
  table.insert(lines, string.rep("-", 60))
  table.insert(lines, "")

  -- Add output
  if entry.output and entry.output ~= "" then
    -- Handle string output (split by lines)
    if type(entry.output) == "string" then
      -- Use vim.split to properly handle all lines including empty ones
      local output_lines = vim.split(entry.output, '\n', { plain = true })
      for _, line in ipairs(output_lines) do
        table.insert(lines, line)
      end
    -- Handle table output
    elseif type(entry.output) == "table" and #entry.output > 0 then
      for _, line in ipairs(entry.output) do
        table.insert(lines, line)
      end
    end
  else
    table.insert(lines, "(No output captured)")
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Store current tab if we need to return to it
  local current_tab = nil
  if focus == false then
    current_tab = vim.api.nvim_get_current_tabpage()
  end

  -- Open in new tab
  vim.cmd("tabnew")
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(new_win, buf)

  -- Set buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "terminal-history-output", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "Terminal Output: " .. entry.command:gsub("\n", " "):sub(1, 30))

  -- Return to original tab if focus is false
  if focus == false and current_tab then
    -- Use pcall to safely attempt to return to the original tab
    local ok, err = pcall(vim.api.nvim_set_current_tabpage, current_tab)
    if not ok then
      -- If the original tab is invalid, try to find the Telescope window
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local win_buf = vim.api.nvim_win_get_buf(win)
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = win_buf })
        if filetype == "TelescopePrompt" then
          vim.api.nvim_set_current_win(win)
          break
        end
      end
    end
  end
end

-- Main picker function
function M.terminal_history_picker(opts)
  opts = opts or {}

  -- Get terminal ID
  local terminal_id = opts.terminal_id or core.get_active_terminal_id()

  if not terminal_id then
    vim.notify("No active terminal found", vim.log.levels.WARN)
    return
  end

  -- Get history from core or storage
  local history = core.get_history(terminal_id)

  if not history or #history == 0 then
    vim.notify("No history for terminal #" .. terminal_id, vim.log.levels.INFO)
    return
  end

  -- Create entries in reverse order (newest first)
  local entries = {}
  for i = #history, 1, -1 do
    local entry = vim.tbl_deep_extend("force", {}, history[i])
    entry.index = i
    entry.terminal_id = terminal_id
    table.insert(entries, entry)
  end

  -- Apply telescope theme if configured
  local theme_opts = {}
  if config.options.ui.telescope and config.options.ui.telescope.theme then
    local themes = require("telescope.themes")
    if themes["get_" .. config.options.ui.telescope.theme] then
      theme_opts = themes["get_" .. config.options.ui.telescope.theme]({})
    end
  end

  -- Merge options
  opts = vim.tbl_deep_extend("force", theme_opts, opts)

  -- Create picker
  pickers
    .new(opts, {
      prompt_title = string.format("Terminal History #%d", terminal_id),

      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = function(e)
              return format_entry(e.value)
            end,
            ordinal = entry.command .. " " .. os.date("%H:%M:%S", entry.timestamp),
          }
        end,
      }),

      sorter = conf.generic_sorter(opts),

      previewer = command_previewer(),

      attach_mappings = function(prompt_bufnr, map)
        -- Toggle wrap in preview window
        map("i", "<C-w>", function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          if picker.previewer and picker.previewer.state and picker.previewer.state.winid then
            local winid = picker.previewer.state.winid
            if vim.api.nvim_win_is_valid(winid) then
              local current_wrap = vim.api.nvim_get_option_value("wrap", { win = winid })
              picker.previewer.wrap = not current_wrap
              vim.api.nvim_set_option_value("wrap", not current_wrap, { win = winid })
              vim.notify("Preview wrap: " .. (not current_wrap and "ON" or "OFF"), vim.log.levels.INFO)
            end
          end
        end)

        map("n", "<C-w>", function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          if picker.previewer and picker.previewer.state and picker.previewer.state.winid then
            local winid = picker.previewer.state.winid
            if vim.api.nvim_win_is_valid(winid) then
              local current_wrap = vim.api.nvim_get_option_value("wrap", { win = winid })
              picker.previewer.wrap = not current_wrap
              vim.api.nvim_set_option_value("wrap", not current_wrap, { win = winid })
              vim.notify("Preview wrap: " .. (not current_wrap and "ON" or "OFF"), vim.log.levels.INFO)
            end
          end
        end)

        -- Default action: copy output to new buffer with focus
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            copy_output_to_buffer(selection.value, true)
          end
        end)

        -- Copy command to clipboard
        map("i", "<C-y>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            vim.fn.setreg("+", selection.value.command)
            vim.notify("Command copied to clipboard", vim.log.levels.INFO)
          end
        end)

        -- Copy output to clipboard
        map("i", "<C-o>", function()
          local selection = action_state.get_selected_entry()
          if selection and selection.value.output then
            local output_text
            if type(selection.value.output) == "string" then
              output_text = selection.value.output
            elseif type(selection.value.output) == "table" then
              output_text = table.concat(selection.value.output, "\n")
            end
            if output_text then
              vim.fn.setreg("+", output_text)
              vim.notify("Output copied to clipboard", vim.log.levels.INFO)
            end
          end
        end)

        -- Open output in new buffer without focus (stay in Telescope)
        map("i", "<C-b>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            copy_output_to_buffer(selection.value, false)
            vim.notify("Output opened in new buffer", vim.log.levels.INFO)
          end
        end)

        -- Re-run command in terminal
        map("i", "<C-r>", function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            -- Find or create terminal
            local term_buf = nil
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal" then
                term_buf = buf
                break
              end
            end

            if term_buf then
              -- Switch to terminal buffer
              vim.cmd("buffer " .. term_buf)
              -- Send command
              vim.api.nvim_chan_send(vim.b.terminal_job_id, selection.value.command .. "\n")
            else
              vim.notify("No terminal buffer found", vim.log.levels.WARN)
            end
          end
        end)

        return true
      end,
    })
    :find()
end

-- Select terminal ID for action
function M.select_terminal_for_action(action)
  local sessions = storage.get_all_sessions()

  if #sessions == 0 then
    vim.notify("No terminal sessions found", vim.log.levels.WARN)
    return
  end

  -- Create picker for terminal selection
  pickers
    .new({}, {
      prompt_title = "Select Terminal for " .. action,

      finder = finders.new_table({
        results = sessions,
        entry_maker = function(session)
          local display = string.format(
            "Terminal #%d | Started: %s | Commands: %d",
            session.id,
            os.date("%Y-%m-%d %H:%M", session.start_time),
            session.command_count or 0
          )

          return {
            value = session,
            display = display,
            ordinal = tostring(session.id),
          }
        end,
      }),

      sorter = conf.generic_sorter({}),

      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()

          if selection then
            local term_id = selection.value.id

            -- Perform action based on type
            if action == "clear" then
              core.clear_history(term_id)
              vim.notify("History cleared for terminal #" .. term_id, vim.log.levels.INFO)
            elseif action == "export" then
              -- Ask for filename
              vim.ui.input({
                prompt = "Export filename: ",
                default = string.format("terminal_%d_history.txt", term_id),
              }, function(filename)
                if filename then
                  if storage.export_history(term_id, filename, "text") then
                    vim.notify("History exported to " .. filename, vim.log.levels.INFO)
                  else
                    vim.notify("Failed to export history", vim.log.levels.ERROR)
                  end
                end
              end)
            elseif action == "show" then
              require("terminal-history.ui").show_terminal_history(term_id)
            elseif action == "telescope" then
              M.terminal_history_picker({ terminal_id = term_id })
            end
          end
        end)

        return true
      end,
    })
    :find()
end

-- Picker for selecting specific terminal history
function M.select_terminal_history()
  M.select_terminal_for_action("telescope")
end

-- Register as Telescope extension
function M.setup()
  telescope.register_extension({
    setup = function(ext_config, config)
      -- Extension setup if needed
    end,
    exports = {
      terminal_history = M.terminal_history_picker,
      select_terminal = M.select_terminal_history,
    },
  })
end

return M
