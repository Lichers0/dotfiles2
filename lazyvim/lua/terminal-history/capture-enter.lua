-- Simple Enter-based capture: command = line before Enter, output = everything after
local M = {}
local debug = require("terminal-history.debug")

M.terminals = {}

-- Setup Enter-based capture
function M.setup(bufnr)
  local core = require("terminal-history.core")
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then
    return
  end

  local terminal = core.get_terminal(term_id)
  if not terminal then
    return
  end


  -- Initialize state for this terminal
  M.terminals[bufnr] = {
    term_id = term_id,
    last_command_line = nil,
    last_command_line_num = 0,
    waiting_for_output = false,
    command_text = "",
    output_start_line = 0,
  }

  -- Intercept Enter key
  vim.keymap.set(
    "t",
    "<CR>",
    '<CR><Cmd>lua require("terminal-history.capture-enter").on_enter(' .. bufnr .. ")<CR>",
    { buffer = bufnr, silent = true, noremap = false }
  )

end

-- Called when Enter is pressed
function M.on_enter(bufnr)
  local state = M.terminals[bufnr]
  if not state then
    return
  end

  -- Get the line where Enter was pressed (before Enter is processed)
  vim.schedule(function()
    -- Small delay to let the command be visible in buffer
    vim.defer_fn(function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local line_count = #lines

      -- Find the last non-empty line (this should be our command)
      local command_line = ""
      local command_line_num = 0

      for i = line_count, 1, -1 do
        if lines[i] and lines[i] ~= "" then
          command_line = lines[i]
          command_line_num = i
          break
        end
      end

      if command_line ~= "" then
        -- This is our command - save it
        state.command_text = command_line
        state.output_start_line = command_line_num + 1
        state.waiting_for_output = true


        -- Schedule output capture after command executes
        vim.defer_fn(function()
          M.capture_output(bufnr)
        end, 500) -- Wait 500ms for command to execute
      end
    end, 50) -- Small delay to let Enter process
  end)
end

-- Capture output after command
function M.capture_output(bufnr)
  local state = M.terminals[bufnr]
  if not state or not state.waiting_for_output then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local output_lines = {}

  -- Get all lines after the command line
  if state.output_start_line > 0 and state.output_start_line <= #lines then
    for i = state.output_start_line, #lines do
      if lines[i] then
        table.insert(output_lines, lines[i])
      end
    end
  end

  local output = table.concat(output_lines, "\n")

  -- Save to history
  local core = require("terminal-history.core")
  local entry = {
    id = os.time() * 1000 + math.random(1000),
    terminal_id = state.term_id,
    command = state.command_text,
    output = output,
    timestamp = os.time(),
    duration = 0,
    cwd = vim.fn.getcwd(),
  }

  core.add_to_history(state.term_id, entry)


  -- Show notification

  -- Reset state
  state.waiting_for_output = false
  state.command_text = ""
end

-- Alternative: Capture everything between two Enter presses
function M.setup_between_enters(bufnr)
  local core = require("terminal-history.core")
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then
    return
  end

  local terminal = core.get_terminal(term_id)
  if not terminal then
    return
  end


  -- State for this method
  local state = {
    term_id = term_id,
    last_enter_line = 0,
    last_buffer_snapshot = {},
  }

  -- Capture on every Enter
  vim.keymap.set(
    "t",
    "<CR>",
    function()
        -- Send Enter to terminal
        vim.api.nvim_feedkeys("\r", "n", false)

        -- Capture after a delay
        vim.defer_fn(function()
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

          -- Find what's new since last Enter
          local new_content = {}
          local start_line = state.last_enter_line + 1

          if start_line > 0 and start_line <= #lines then
            -- Get the command (should be on the line where we pressed Enter)
            local command = ""
            if state.last_enter_line > 0 and state.last_enter_line <= #lines then
              command = lines[state.last_enter_line] or ""
            end

            -- Get everything after as output
            for i = start_line, #lines do
              if lines[i] then
                table.insert(new_content, lines[i])
              end
            end

            if command ~= "" and #command > 0 then
              local entry = {
                id = os.time() * 1000 + math.random(1000),
                terminal_id = term_id,
                command = command,
                output = table.concat(new_content, "\n"),
                timestamp = os.time(),
                duration = 0,
                cwd = vim.fn.getcwd(),
              }

              core.add_to_history(term_id, entry)

            end
          end

          -- Update state for next capture
          state.last_enter_line = #lines
          state.last_buffer_snapshot = lines
        end, 300)
      end,
    {
      buffer = bufnr,
      silent = true,
      noremap = true
    }
  )
end

return M

