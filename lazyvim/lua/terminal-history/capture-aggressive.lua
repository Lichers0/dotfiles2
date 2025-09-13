-- Most aggressive capture method - monitors all terminal changes
local M = {}
local debug = require("terminal-history.debug")

-- Setup aggressive capture
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


  -- Store state
  local last_lines = {}
  local potential_commands = {}
  local last_enter_time = 0

  -- Hook into terminal mode enter
  vim.api.nvim_create_autocmd({ "TermEnter", "BufEnter" }, {
    buffer = bufnr,
    callback = function()
    end,
  })

  -- Monitor every key press in terminal mode
  vim.keymap.set(
    "t",
    "<CR>",
    '<CR><Cmd>lua require("terminal-history.capture-aggressive").on_enter(' .. bufnr .. ")<CR>",
    { buffer = bufnr, silent = true, noremap = false }
  )

  -- Also monitor common command keys
  local keys = {
    "<Space>",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "-",
    "_",
    "/",
    ".",
  }

  for _, key in ipairs(keys) do
    vim.keymap.set(
      "t",
      key,
      key .. '<Cmd>lua require("terminal-history.capture-aggressive").on_key(' .. bufnr .. ', "' .. key .. '")<CR>',
      { buffer = bufnr, silent = true, noremap = false }
    )
  end

  -- Very aggressive: check buffer every 500ms
  local timer = vim.loop.new_timer()
  local last_content = ""
  local command_line = ""

  timer:start(
    500,
    500,
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        timer:stop()
        return
      end

      -- Get current buffer content
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Check if content changed
      if content ~= last_content then
        -- Find the last line with content
        local last_line = ""
        for i = #lines, 1, -1 do
          if lines[i] and lines[i] ~= "" then
            last_line = lines[i]
            break
          end
        end


        -- Try to extract command from last line
        -- Look for common patterns that indicate a command was typed
        local patterns = {
          "([^$#>]+)$", -- Everything after prompt chars
          "^%s*(.+)$", -- Everything with leading space trimmed
        }

        for _, pattern in ipairs(patterns) do
          local potential_cmd = last_line:match(pattern)
          if potential_cmd and #potential_cmd > 0 then
            -- Clean up the command
            potential_cmd = potential_cmd:gsub("^[%s$#>]+", ""):gsub("%s+$", "")

            -- Check if this looks like a command (has letters/numbers)
            if potential_cmd:match("[%w]") and #potential_cmd > 0 then
              -- Store as potential command
              if potential_cmd ~= command_line then
                command_line = potential_cmd
              end
            end
          end
        end

        last_content = content
      end
    end)
  )

  -- Store timer for cleanup
  terminal.aggressive_timer = timer

  -- Store state for this buffer
  M.buffers = M.buffers or {}
  M.buffers[bufnr] = {
    term_id = term_id,
    command_line = "",
    last_enter = 0,
  }
end

-- Called when Enter is pressed
function M.on_enter(bufnr)

  local data = M.buffers and M.buffers[bufnr]
  if not data then
    return
  end

  -- Mark that enter was pressed
  data.last_enter = vim.loop.now()

  -- Schedule command capture after a delay
  vim.defer_fn(function()
    -- Get the line before where Enter was pressed
    local lines = vim.api.nvim_buf_get_lines(bufnr, -10, -1, false)

    -- Look for command in recent lines
    for i = #lines, 1, -1 do
      local line = lines[i]
      if line and line ~= "" then
        -- Extract command
        local cmd = line:gsub("^.*[%$#>]%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")

        if cmd and #cmd > 0 and cmd:match("[%w]") then
          -- Save command
          local core = require("terminal-history.core")
          local entry = {
            id = os.time() * 1000 + math.random(1000),
            terminal_id = data.term_id,
            command = cmd,
            output = "",
            timestamp = os.time(),
            duration = 0,
            cwd = vim.fn.getcwd(),
          }

          local config = require("terminal-history.config")
          local utils = require("terminal-history.utils")

          if not utils.should_ignore_command(cmd, config.options) then
            core.add_to_history(data.term_id, entry)
          end

          break
        end
      end
    end
  end, 200)
end

-- Called when a key is pressed
function M.on_key(bufnr, key)
  local data = M.buffers and M.buffers[bufnr]
  if not data then
    return
  end

  -- Build command line
  if key == "<Space>" then
    data.command_line = data.command_line .. " "
  else
    data.command_line = data.command_line .. key
  end

end

-- Manual capture function that can be called directly
function M.capture_current_line()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "terminal" then
    vim.notify("Not in a terminal buffer", vim.log.levels.WARN)
    return
  end

  -- Get current line
  local line = vim.api.nvim_get_current_line()
  local cmd = line:gsub("^.*[%$#>]%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")

  if cmd and #cmd > 0 then
    local core = require("terminal-history.core")
    local term_id = core.get_terminal_id(bufnr)

    if term_id then
      local entry = {
        id = os.time() * 1000 + math.random(1000),
        terminal_id = term_id,
        command = cmd,
        output = "",
        timestamp = os.time(),
        duration = 0,
        cwd = vim.fn.getcwd(),
      }

      core.add_to_history(term_id, entry)
      vim.notify("Manually captured: " .. cmd, vim.log.levels.INFO)
    end
  else
    vim.notify("No command found on current line", vim.log.levels.WARN)
  end
end

return M

