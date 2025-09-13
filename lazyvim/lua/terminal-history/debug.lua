local M = {}

-- Debug messages storage
M.messages = {}
M.enabled = true
M.max_messages = 100

-- Add debug message
function M.log(message)
  if not M.enabled then
    return
  end

  table.insert(M.messages, {
    time = os.date("%H:%M:%S"),
    msg = message,
  })

  -- Limit messages
  if #M.messages > M.max_messages then
    table.remove(M.messages, 1)
  end

  -- Also print to Neovim messages (without modifying buffer)
  vim.schedule(function()
    -- Replace newlines for notification as well
    local notify_msg = message:gsub('\n', ' ↵ ')
    vim.notify("[TH Debug] " .. notify_msg, vim.log.levels.DEBUG)
  end)
end

-- Show debug messages in a buffer
function M.show()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local lines = { "=== Terminal History Debug Messages ===", "" }

  if #M.messages == 0 then
    table.insert(lines, "No debug messages. Enable debug mode with :TerminalHistoryDebug on")
  else
    for _, msg in ipairs(M.messages) do
      -- Replace newlines with a visible marker
      local message_text = msg.msg:gsub('\n', ' ↵ ')
      table.insert(lines, string.format("[%s] %s", msg.time, message_text))
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Open in split
  vim.cmd("split")
  vim.api.nvim_set_current_buf(buf)

  -- Set keymap to close
  vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, noremap = true, silent = true })
end

-- Clear debug messages
function M.clear()
  M.messages = {}
  vim.notify("Debug messages cleared", vim.log.levels.INFO)
end

-- Enable/disable debug
function M.set_enabled(enabled)
  M.enabled = enabled
  if enabled then
    M.log("Debug mode enabled")
  end
end

return M

