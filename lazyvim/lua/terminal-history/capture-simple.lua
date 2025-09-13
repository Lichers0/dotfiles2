-- Simplest possible capture method - just track terminal content changes
local M = {}
local debug = require('terminal-history.debug')

-- Setup simple capture
function M.setup(bufnr)
  local core = require('terminal-history.core')
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then return end
  
  local terminal = core.get_terminal(term_id)
  if not terminal then return end
  
  
  -- Store last known state
  local last_content = ""
  local last_line_count = 0
  
  -- Simple timer-based capture
  local timer = vim.loop.new_timer()
  timer:start(1000, 1000, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      timer:stop()
      return
    end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local current_content = table.concat(lines, "\n")
    local current_line_count = #lines
    
    -- Check if content changed
    if current_content ~= last_content and current_line_count > last_line_count then
      -- Get the new lines
      local new_lines = {}
      for i = last_line_count + 1, current_line_count do
        if lines[i] then
          table.insert(new_lines, lines[i])
        end
      end
      
      -- Try to detect commands in new lines
      for _, line in ipairs(new_lines) do
        -- Simple heuristic: if line contains common command patterns
        if line:match("^%s*[%w%-_/]+") and not line:match("^%s*$") then
          -- Extract potential command
          local cmd = line:gsub("^.*[$#>]%s*", ""):gsub("^%s*", "")
          
          if cmd and #cmd > 1 and not cmd:match("^%^") then
            local entry = {
              id = os.time() * 1000 + math.random(1000),
              terminal_id = term_id,
              command = cmd,
              output = "",
              timestamp = os.time(),
              duration = 0,
              cwd = vim.fn.getcwd(),
            }
            
            local config = require('terminal-history.config')
            local utils = require('terminal-history.utils')
            
            if not utils.should_ignore_command(cmd, config.options) then
              core.add_to_history(term_id, entry)
            end
          end
        end
      end
      
      last_content = current_content
      last_line_count = current_line_count
    end
  end))
  
  -- Store timer reference for cleanup
  terminal.capture_timer = timer
end

return M