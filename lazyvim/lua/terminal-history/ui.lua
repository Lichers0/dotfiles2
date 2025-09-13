local M = {}

-- Buffer for history display
M.history_bufnr = nil
M.current_terminal_id = nil
M.current_history = nil
M.selected_index = 1

-- Create or get history buffer
function M.get_or_create_buffer()
  if M.history_bufnr and vim.api.nvim_buf_is_valid(M.history_bufnr) then
    return M.history_bufnr
  end
  
  M.history_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = M.history_bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = M.history_bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = M.history_bufnr })
  vim.api.nvim_set_option_value('filetype', 'terminal-history', { buf = M.history_bufnr })
  
  return M.history_bufnr
end

-- Format history entry for display
function M.format_entry(entry, index, config)
  local date_format = config.ui.date_format or '%H:%M:%S'
  local time_str = os.date(date_format, entry.timestamp)
  
  -- Заменяем переносы строк на пробелы или специальный символ для отображения
  local command_display = entry.command:gsub('\n', ' ↵ ')
  
  local line = string.format('[%d] %s %s', index, time_str, command_display)
  
  if config.ui.show_terminal_id then
    line = string.format('[T:%d] %s', entry.terminal_id, line)
  end
  
  return line
end

-- Show terminal history
function M.show_terminal_history(term_id)
  local core = require('terminal-history.core')
  local config = require('terminal-history.config')
  
  -- Get terminal ID
  term_id = term_id or core.get_active_terminal_id()
  if not term_id then
    vim.notify('No active terminal found', vim.log.levels.WARN)
    return
  end
  
  -- Get history
  local history = core.get_history(term_id)
  if not history or #history == 0 then
    vim.notify('No history for terminal #' .. term_id, vim.log.levels.INFO)
    return
  end
  
  M.current_terminal_id = term_id
  M.current_history = history
  
  -- Create buffer content
  local lines = {}
  table.insert(lines, '=== Terminal History #' .. term_id .. ' ===')
  table.insert(lines, 'Commands: ' .. #history .. ' | <CR>: view (reuse window) | o: new window | q: quit')
  table.insert(lines, string.rep('-', 60))
  
  for i = #history, 1, -1 do
    table.insert(lines, M.format_entry(history[i], i, config.options))
  end
  
  -- Create and fill buffer
  local buf = M.get_or_create_buffer()
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  
  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'TerminalHistory:#' .. term_id)
  
  -- Open in current window
  vim.api.nvim_set_current_buf(buf)
  
  -- Setup keymaps
  M.setup_buffer_keymaps(buf)
  
  -- Move cursor to first history entry
  vim.api.nvim_win_set_cursor(0, {4, 0})
end

-- Track output window
M.output_win = nil
M.output_buf = nil

-- Show command output in detail (reuse window if exists)
function M.show_command_output(force_new_window)
  if not M.current_history then return end
  
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  -- Skip header lines
  if line_num <= 3 then return end
  
  -- Calculate actual history index (reversed)
  local index = #M.current_history - (line_num - 4) + 1
  if index < 1 or index > #M.current_history then return end
  
  local entry = M.current_history[index]
  if not entry then return end
  
  -- Check if we should reuse existing window
  local reuse_window = false
  if not force_new_window and M.output_win and vim.api.nvim_win_is_valid(M.output_win) then
    -- Window exists, reuse it
    reuse_window = true
  end
  
  -- Create or reuse buffer
  local buf
  if reuse_window and M.output_buf and vim.api.nvim_buf_is_valid(M.output_buf) then
    buf = M.output_buf
    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  else
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'sh', { buf = buf })
    M.output_buf = buf
  end
  
  -- Prepare content
  local lines = {}
  table.insert(lines, '=== Command Output ===')
  table.insert(lines, 'Terminal: #' .. (entry.terminal_id or M.current_terminal_id))
  
  -- Handle multi-line commands
  if entry.command and entry.command:find('\n') then
    table.insert(lines, 'Command (multi-line):')
    for cmd_line in entry.command:gmatch('[^\n]*') do
      table.insert(lines, '  ' .. cmd_line)
    end
  else
    table.insert(lines, 'Command: ' .. (entry.command or ''))
  end
  
  table.insert(lines, 'Time: ' .. os.date('%Y-%m-%d %H:%M:%S', entry.timestamp))
  table.insert(lines, 'Duration: ' .. (entry.duration or 0) .. 's')
  table.insert(lines, 'CWD: ' .. (entry.cwd or 'unknown'))
  table.insert(lines, string.rep('-', 60))
  
  -- Add output
  if entry.output and entry.output ~= '' then
    -- Use vim.split to properly handle empty lines
    local output_lines = vim.split(entry.output, '\n', { plain = true })
    for _, line in ipairs(output_lines) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, '(no output)')
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  
  -- Open or focus window
  if reuse_window then
    -- Switch to existing window and update buffer
    vim.api.nvim_win_set_buf(M.output_win, buf)
    
    -- Optionally focus the window
    -- vim.api.nvim_set_current_win(M.output_win)
    
    -- Visual feedback that window was updated
    vim.schedule(function()
      -- Briefly highlight the window
      local hl_group = 'IncSearch'
      vim.api.nvim_set_option_value('winhl', 'Normal:' .. hl_group, { win = M.output_win })
      vim.defer_fn(function()
        vim.api.nvim_set_option_value('winhl', '', { win = M.output_win })
      end, 200)
    end)
  else
    -- Create new split window
    local current_win = vim.api.nvim_get_current_win()
    vim.cmd('split')
    M.output_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_buf(buf)
    
    -- Return focus to history window
    vim.api.nvim_set_current_win(current_win)
  end
  
  -- Setup keymaps for output buffer
  vim.keymap.set('n', 'q', ':close<CR>', { buffer = buf, noremap = true, silent = true })
  
  -- Add autocmd to track when window is closed
  vim.api.nvim_create_autocmd('WinClosed', {
    buffer = buf,
    once = true,
    callback = function()
      if M.output_win == tonumber(vim.fn.expand('<afile>')) then
        M.output_win = nil
        M.output_buf = nil
      end
    end
  })
end

-- Force open in new window
function M.show_command_output_new_window()
  M.show_command_output(true)
end

-- List all terminals
function M.list_all_terminals()
  local core = require('terminal-history.core')
  local storage = require('terminal-history.storage')
  
  -- Get active terminals
  local active = core.list_terminals()
  
  -- Get saved sessions
  local sessions = storage.get_all_sessions()
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
  
  local lines = {}
  table.insert(lines, '=== Terminal Sessions ===')
  table.insert(lines, '')
  table.insert(lines, 'Active Terminals:')
  table.insert(lines, string.rep('-', 40))
  
  if #active > 0 then
    for _, term in ipairs(active) do
      local status = term.is_active and '[ACTIVE]' or '[INACTIVE]'
      table.insert(lines, string.format('%s Terminal #%d - %d commands', 
        status, term.id, term.history_count))
    end
  else
    table.insert(lines, '  No active terminals')
  end
  
  table.insert(lines, '')
  table.insert(lines, 'Saved Sessions:')
  table.insert(lines, string.rep('-', 40))
  
  local has_sessions = false
  for term_id, session in pairs(sessions) do
    has_sessions = true
    local time_str = os.date('%Y-%m-%d %H:%M', session.last_updated or 0)
    table.insert(lines, string.format('  Terminal #%s - %s', 
      term_id, time_str))
  end
  
  if not has_sessions then
    table.insert(lines, '  No saved sessions')
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  
  -- Open in current window
  vim.api.nvim_set_current_buf(buf)
  
  -- Setup keymap to close
  vim.keymap.set('n', 'q', ':close<CR>', { buffer = buf, noremap = true, silent = true })
end

-- Copy command to clipboard
function M.copy_command()
  if not M.current_history then return end
  
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  if line_num <= 3 then return end
  
  local index = #M.current_history - (line_num - 4) + 1
  if index < 1 or index > #M.current_history then return end
  
  local entry = M.current_history[index]
  if entry and entry.command then
    vim.fn.setreg('+', entry.command)
    vim.notify('Command copied to clipboard', vim.log.levels.INFO)
  end
end

-- Repeat command in terminal
function M.repeat_command()
  if not M.current_history or not M.current_terminal_id then return end
  
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  if line_num <= 3 then return end
  
  local index = #M.current_history - (line_num - 4) + 1
  if index < 1 or index > #M.current_history then return end
  
  local entry = M.current_history[index]
  if not entry or not entry.command then return end
  
  -- Find terminal buffer
  local core = require('terminal-history.core')
  local terminal = core.get_terminal(M.current_terminal_id)
  
  if terminal and vim.api.nvim_buf_is_valid(terminal.bufnr) then
    -- Switch to terminal buffer
    vim.api.nvim_set_current_buf(terminal.bufnr)
    
    -- Send command to terminal
    vim.api.nvim_chan_send(vim.b.terminal_job_id, entry.command .. '\n')
    
    vim.notify('Command sent to terminal', vim.log.levels.INFO)
  else
    vim.notify('Terminal not found or closed', vim.log.levels.WARN)
  end
end

-- Delete history entry
function M.delete_entry()
  if not M.current_history or not M.current_terminal_id then return end
  
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  if line_num <= 3 then return end
  
  local index = #M.current_history - (line_num - 4) + 1
  if index < 1 or index > #M.current_history then return end
  
  -- Remove from history
  table.remove(M.current_history, index)
  
  -- Update storage
  local storage = require('terminal-history.storage')
  storage.save_history(M.current_terminal_id, M.current_history)
  
  -- Update buffer
  M.show_terminal_history(M.current_terminal_id)
  
  vim.notify('Entry deleted', vim.log.levels.INFO)
end

-- Setup buffer keymaps
function M.setup_buffer_keymaps(buf)
  local opts = { noremap = true, silent = true }
  local config = require('terminal-history.config')
  local keymaps = config.options.keymaps
  
  -- View output (reuse window)
  vim.keymap.set('n', keymaps.open_in_buffer, 
    ':lua require("terminal-history.ui").show_command_output()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- View output in new window (Shift-Enter or 'o')
  vim.keymap.set('n', 'o',
    ':lua require("terminal-history.ui").show_command_output_new_window()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  vim.keymap.set('n', '<S-CR>',
    ':lua require("terminal-history.ui").show_command_output_new_window()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- Copy command
  vim.keymap.set('n', keymaps.copy_command,
    ':lua require("terminal-history.ui").copy_command()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- Delete entry
  vim.keymap.set('n', keymaps.delete_entry,
    ':lua require("terminal-history.ui").delete_entry()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- Repeat command
  vim.keymap.set('n', 'r',
    ':lua require("terminal-history.ui").repeat_command()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- Quit
  vim.keymap.set('n', 'q', ':close<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
  
  -- Refresh
  vim.keymap.set('n', 'R',
    ':lua require("terminal-history.ui").show_terminal_history()<CR>', vim.tbl_extend('force', opts, { buffer = buf }))
end

return M