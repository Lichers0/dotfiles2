local M = {}
local debug = require("terminal-history.debug")

-- Debug mode
M.debug = false

-- Pattern to detect command prompts - more flexible patterns
local PROMPT_PATTERNS = {
  "$ ", -- Most basic prompt
  "# ", -- Root prompt
  "> ", -- Simple prompt
  "❯ ", -- Fish/zsh prompt
  "➜ ", -- Oh-my-zsh prompt
  ">>> ", -- Python prompt
  ">> ", -- Continuation prompt
  "%$ ", -- With percent
  "%# ", -- Root with percent
  "\\$ ", -- Escaped dollar
  "] $ ", -- With bracket
  "] # ", -- Root with bracket
  "%)%s*$", -- Closing paren at end
  "%]%s*$", -- Closing bracket at end
}

-- Setup command capture for a terminal buffer
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


  -- Variables for tracking command state
  local last_line = ""
  local waiting_for_command = true
  local current_command = nil
  local command_start_time = nil
  local output_lines = {}
  local prompt_detected = false

  -- Function to detect if line might be a prompt
  local function is_prompt_line(line)
    if not line or line == "" then
      return false
    end

    -- Check for common prompt patterns
    for _, pattern in ipairs(PROMPT_PATTERNS) do
      if line:find(pattern) then
        return true
      end
    end

    -- Additional heuristic: line ends with $ or # or > with possible spaces
    if line:match("[%$#>]%s*$") then
      return true
    end

    return false
  end

  -- Function to extract command from line
  local function extract_command(line)
    if not line then
      return nil
    end

    -- Try to find command after common prompt characters
    local patterns = {
      "[%$#>]%s+(.+)$", -- After $, #, or >
      "❯%s+(.+)$", -- After fish prompt
      "➜%s+(.+)$", -- After oh-my-zsh
      ">>>%s+(.+)$", -- Python
      "%]%s+(.+)$", -- After bracket
      "%)%s+(.+)$", -- After paren
    }

    for _, pattern in ipairs(patterns) do
      local cmd = line:match(pattern)
      if cmd then
        return vim.trim(cmd)
      end
    end

    -- Fallback: get everything after last space if line looks like prompt
    if is_prompt_line(line) then
      local parts = vim.split(line, "%s+")
      if #parts > 1 then
        -- Return everything after the prompt part
        local prompt_end = line:find("[%$#>]")
        if prompt_end then
          local cmd = line:sub(prompt_end + 1)
          return vim.trim(cmd)
        end
      end
    end

    return nil
  end

  -- Alternative approach: monitor terminal job directly
  local term_job_id = vim.b[bufnr].terminal_job_id
  if term_job_id then
    -- Set up autocmd to capture when user sends input
    vim.api.nvim_create_autocmd("TermRequest", {
      buffer = bufnr,
      callback = function(args)
      end,
    })
  end

  -- Attach to buffer changes
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, _, first_line, last_line_new, last_line_old, byte_count)
      -- Check if terminal is still being tracked
      if not terminal.tracking_enabled then
        return
      end

      -- Get all lines from buffer
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      if #lines == 0 then
        return
      end

      -- Get the last non-empty line
      local current_line = ""
      for i = #lines, 1, -1 do
        if lines[i] and lines[i] ~= "" then
          current_line = lines[i]
          break
        end
      end

      if current_line ~= last_line then
      end

      -- Check if this looks like a command being typed
      if current_line ~= last_line then
        -- Check if previous line was a prompt and now we have text after it
        if is_prompt_line(last_line) and not is_prompt_line(current_line) then
          -- User started typing a command
          local cmd = extract_command(current_line)
          if not cmd then
            -- Maybe the whole line after prompt is the command
            cmd = current_line
          end

          if cmd and cmd ~= "" then
            waiting_for_command = false
            current_command = cmd
            command_start_time = os.time()
            output_lines = {}
            prompt_detected = true

          end
        elseif current_command and is_prompt_line(current_line) then
          -- New prompt appeared, save the previous command
          if prompt_detected then
            local entry = {
              id = os.time() * 1000 + math.random(1000),
              terminal_id = term_id,
              command = current_command,
              output = table.concat(output_lines, "\n"),
              timestamp = command_start_time or os.time(),
              duration = os.time() - (command_start_time or os.time()),
              cwd = vim.fn.getcwd(),
            }

            -- Filter check
            local config = require("terminal-history.config")
            local utils = require("terminal-history.utils")

            if not utils.should_ignore_command(current_command, config.options) then
              core.add_to_history(term_id, entry)
            end
          end

          -- Reset for next command
          current_command = nil
          waiting_for_command = true
          prompt_detected = false
          output_lines = {}
        elseif current_command and not waiting_for_command then
          -- Capture output
          table.insert(output_lines, current_line)
        end

        last_line = current_line
      end
    end,

    on_detach = function()
      -- Save final command if there is one
      if current_command and prompt_detected then
        local entry = {
          id = os.time() * 1000 + math.random(1000),
          terminal_id = term_id,
          command = current_command,
          output = table.concat(output_lines, "\n"),
          timestamp = command_start_time or os.time(),
          duration = os.time() - (command_start_time or os.time()),
          cwd = vim.fn.getcwd(),
        }
        core.add_to_history(term_id, entry)
      end
    end,
  })
end

-- Enable/disable debug mode
function M.set_debug(enabled)
  M.debug = enabled
  debug.set_enabled(enabled)
end

return M

