-- Alternative capture method using terminal input interception
local M = {}
local debug = require("terminal-history.debug")

M.debug = false

-- Setup alternative capture method
function M.setup_terminal_capture(bufnr)
  local core = require("terminal-history.core")
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then
    return
  end

  local terminal = core.get_terminal(term_id)
  if not terminal then
    return
  end

  -- Store command being built
  local current_input = ""
  local command_start_time = nil
  local last_output_line = 0

  -- Override terminal send to capture commands
  local original_chan_send = vim.api.nvim_chan_send
  local term_chan_id = vim.b[bufnr].terminal_job_id

  -- Monitor what's sent to terminal
  local function capture_input(data)
    if not terminal.tracking_enabled then
      return
    end

    -- Check if this is Enter key (command execution)
    if data == "\r" or data == "\n" or data == "\r\n" then
      if current_input and current_input ~= "" then
        command_start_time = os.time()

        -- Schedule capture of output after command executes
        vim.defer_fn(function()
          -- Get buffer lines after command
          local lines = vim.api.nvim_buf_get_lines(bufnr, last_output_line, -1, false)
          local output = table.concat(lines, "\n")

          -- Create history entry
          local entry = {
            id = os.time() * 1000 + math.random(1000),
            terminal_id = term_id,
            command = current_input,
            output = output,
            timestamp = command_start_time,
            duration = 0,
            cwd = vim.fn.getcwd(),
          }

          -- Check filters
          local config = require("terminal-history.config")
          local utils = require("terminal-history.utils")

          if not utils.should_ignore_command(current_input, config.options) then
            core.add_to_history(term_id, entry)
          end

          -- Update last line position
          last_output_line = vim.api.nvim_buf_line_count(bufnr)
        end, 500) -- Wait 500ms for output

        -- Reset input
        current_input = ""
      end
    elseif data == "\127" or data == "\b" then
      -- Backspace
      if #current_input > 0 then
        current_input = current_input:sub(1, -2)
      end
    elseif data == "\027" then
      -- Escape sequences, clear input
      current_input = ""
    elseif data:match("^[%w%s%p]+$") then
      -- Regular characters
      current_input = current_input .. data
    end

    if data ~= "\r" and data ~= "\n" then
    end
  end

  -- Hook into terminal input
  vim.api.nvim_create_autocmd({ "BufEnter", "TermEnter" }, {
    buffer = bufnr,
    callback = function()
      -- Set up input capture for this terminal session
      if vim.b[bufnr].terminal_job_id == term_chan_id then
        -- Store original send function
        vim.g.terminal_history_capturing = true
      end
    end,
  })

  -- Monitor terminal input via remapping in terminal mode
  vim.keymap.set(
    "t",
    "<BS>",
    '<BS><cmd>lua require("terminal-history.capture-alt").on_backspace()<CR>',
    { buffer = bufnr, silent = true, noremap = false }
  )

  -- Store buffer reference
  M.terminals = M.terminals or {}
  M.terminals[bufnr] = {
    term_id = term_id,
    current_input = "",
    last_line = 0,
  }
end

-- Handle backspace
function M.on_backspace()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.terminals and M.terminals[bufnr] then
    local t = M.terminals[bufnr]
    if #t.current_input > 0 then
      t.current_input = t.current_input:sub(1, -2)
    end
  end
end

-- Simple line-based capture
function M.simple_capture(bufnr)
  local core = require("terminal-history.core")
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then
    return
  end

  local terminal = core.get_terminal(term_id)
  if not terminal then
    return
  end

  -- Track commands by line number
  local commands = {}
  local last_prompt_line = 0

  -- Simpler approach: save every Enter press with preceding text
  vim.keymap.set(
    "t",
    "<CR>",
    '<CR><cmd>lua require("terminal-history.capture-alt").capture_on_enter()<CR>',
    { buffer = bufnr, silent = true, noremap = false }
  )

  M.pending_capture = M.pending_capture or {}
  M.pending_capture[bufnr] = {
    term_id = term_id,
  }
end

-- Capture when Enter is pressed
function M.capture_on_enter()
  local bufnr = vim.api.nvim_get_current_buf()
  local data = M.pending_capture and M.pending_capture[bufnr]
  if not data then
    return
  end

  -- Get current line (command that was just entered)
  vim.defer_fn(function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)
    if #lines > 0 then
      local line = lines[1]
      -- Extract command from line (remove prompt)
      local cmd = line:match("[%$#>]%s*(.+)") or line

      if cmd and cmd ~= "" then
        local core = require("terminal-history.core")
        local entry = {
          id = os.time() * 1000 + math.random(1000),
          terminal_id = data.term_id,
          command = vim.trim(cmd),
          output = "", -- Will be captured later
          timestamp = os.time(),
          duration = 0,
          cwd = vim.fn.getcwd(),
        }

        -- Save immediately
        local config = require("terminal-history.config")
        local utils = require("terminal-history.utils")
        if not utils.should_ignore_command(cmd, config.options) then
          core.add_to_history(data.term_id, entry)
        end
      end
    end
  end, 100)
end

return M

