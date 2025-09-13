local M = {}

-- Strip ANSI escape codes from text
function M.strip_ansi(text)
  if not text then return '' end
  -- Remove common ANSI escape sequences
  text = text:gsub('\27%[[0-9;]*m', '')  -- Color codes
  text = text:gsub('\27%[[0-9]*[A-Z]', '') -- Cursor movements
  text = text:gsub('\27%].-\7', '')       -- OSC sequences
  text = text:gsub('\27%[%?%d+[hl]', '')  -- Mode changes
  return text
end

-- Truncate string to max length
function M.truncate(str, max_len)
  if not str then return '' end
  if #str <= max_len then return str end
  return str:sub(1, max_len - 3) .. '...'
end

-- Format duration
function M.format_duration(seconds)
  if not seconds then return '0s' end
  
  if seconds < 1 then
    return string.format('%.2fs', seconds)
  elseif seconds < 60 then
    return string.format('%ds', math.floor(seconds))
  elseif seconds < 3600 then
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format('%dm %ds', mins, secs)
  else
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    return string.format('%dh %dm', hours, mins)
  end
end

-- Get shell name from environment
function M.get_shell()
  local shell = vim.env.SHELL
  if shell then
    return vim.fn.fnamemodify(shell, ':t')
  end
  return 'unknown'
end

-- Check if command should be ignored
function M.should_ignore_command(command, config)
  if not command then return true end
  
  -- Don't trim yet, work with original
  local original = command
  command = vim.trim(command)
  
  -- If command is empty after trim, ignore
  if command == "" then 
    return true 
  end
  
  -- Check minimum length (allow 0 for testing)
  if config.filters.min_command_length > 0 and #command < config.filters.min_command_length then
    return true
  end
  
  -- Check ignore list
  for _, ignored in ipairs(config.filters.ignore_commands) do
    if command == ignored or command:match('^' .. ignored .. '%s') then
      return true
    end
  end
  
  -- Don't ignore lines that look like commands (even with prompts)
  -- This helps when the whole line including prompt is captured
  if original:match('[%$#>]%s*%w+') then
    return false  -- Likely a command with prompt, don't ignore
  end
  
  return false
end

-- Create directory if it doesn't exist
function M.ensure_dir(path)
  local dir = vim.fn.fnamemodify(path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
end

-- Get relative time string
function M.relative_time(timestamp)
  local now = os.time()
  local diff = now - timestamp
  
  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    local mins = math.floor(diff / 60)
    return mins .. ' min' .. (mins > 1 and 's' or '') .. ' ago'
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. ' hour' .. (hours > 1 and 's' or '') .. ' ago'
  else
    local days = math.floor(diff / 86400)
    return days .. ' day' .. (days > 1 and 's' or '') .. ' ago'
  end
end

return M