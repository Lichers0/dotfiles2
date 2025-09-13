local M = {}

-- Active terminals storage
M.terminals = {}
M.last_active_terminal_id = nil

-- Get terminal ID from buffer
function M.get_terminal_id(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype == "terminal" then
    return vim.b[bufnr].terminal_job_id
  end
  return nil
end

-- Register new terminal
function M.register_terminal(bufnr)
  local term_id = M.get_terminal_id(bufnr)
  if not term_id then
    return false
  end

  M.terminals[term_id] = {
    bufnr = bufnr,
    history = {},
    start_time = os.time(),
    cwd = vim.fn.getcwd(),
    name = string.format("Terminal #%d", term_id),
    tracking_enabled = true,
    current_command = nil,
    command_start_line = nil,
    capturing_output = false,
  }

  M.last_active_terminal_id = term_id
  return true
end

-- Unregister terminal (when closed)
function M.unregister_terminal(term_id)
  if M.terminals[term_id] then
    -- Stop capture timer if exists
    if M.terminals[term_id].capture_timer then
      M.terminals[term_id].capture_timer:stop()
      M.terminals[term_id].capture_timer = nil
    end

    -- Save history before removing from active terminals
    local storage = require("terminal-history.storage")
    storage.save_terminal_session(term_id, M.terminals[term_id])
    M.terminals[term_id] = nil
  end
end

-- Get active terminal ID
function M.get_active_terminal_id()
  local bufnr = vim.api.nvim_get_current_buf()
  local term_id = M.get_terminal_id(bufnr)

  if term_id then
    M.last_active_terminal_id = term_id
    return term_id
  end

  return M.last_active_terminal_id
end

-- Get terminal info
function M.get_terminal(term_id)
  return M.terminals[term_id]
end

-- List all terminals
function M.list_terminals()
  local list = {}
  for term_id, data in pairs(M.terminals) do
    table.insert(list, {
      id = term_id,
      name = data.name,
      start_time = data.start_time,
      cwd = data.cwd,
      history_count = #data.history,
      is_active = vim.api.nvim_buf_is_valid(data.bufnr),
    })
  end
  return list
end

-- Toggle tracking for terminal
function M.toggle_tracking(term_id)
  term_id = term_id or M.get_active_terminal_id()
  if M.terminals[term_id] then
    M.terminals[term_id].tracking_enabled = not M.terminals[term_id].tracking_enabled
    return M.terminals[term_id].tracking_enabled
  end
  return nil
end

-- Add command to history
function M.add_to_history(term_id, entry)
  if M.terminals[term_id] and M.terminals[term_id].tracking_enabled then
    table.insert(M.terminals[term_id].history, entry)

    -- Also save to persistent storage
    local storage = require("terminal-history.storage")
    storage.append_to_history(term_id, entry)

    -- Limit in-memory history size
    local config = require("terminal-history.config")
    if #M.terminals[term_id].history > config.options.max_entries_per_terminal then
      table.remove(M.terminals[term_id].history, 1)
    end
  end
end

-- Get terminal history
function M.get_history(term_id)
  if M.terminals[term_id] then
    return M.terminals[term_id].history
  end

  -- Try to load from storage if not in memory
  local storage = require("terminal-history.storage")
  return storage.load_history(term_id)
end

-- Clear terminal history
function M.clear_history(term_id)
  if M.terminals[term_id] then
    M.terminals[term_id].history = {}
  end

  local storage = require("terminal-history.storage")
  storage.clear_history(term_id)
end

-- Setup autocmds for terminal tracking
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("TerminalHistory", { clear = true })

  -- Register new terminals
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      M.register_terminal(args.buf)

      -- Setup command capture for this terminal
      -- Use the simplest method: line-by-line capture with Enter detection
      local capture_lines = require("terminal-history.capture-lines")
      capture_lines.setup(args.buf)
      
      -- Enable line numbers for terminal buffer
      vim.api.nvim_set_option_value('number', true, { win = 0 })
      vim.api.nvim_set_option_value('relativenumber', false, { win = 0 })
      
      -- Setup buffer-local keymap for this terminal
      local config = require("terminal-history.config")
      local keymap = config.options.keymaps.open_history_in_terminal
      if keymap and keymap ~= "" then
        vim.keymap.set(
          "t",
          keymap,
          "<C-\\><C-n>:TerminalHistoryTelescope<CR>",
          { 
            buffer = args.buf,
            silent = true, 
            noremap = true,
            desc = "Open terminal history in Telescope"
          }
        )
      end
    end,
  })

  -- Track active terminal
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "term://*",
    callback = function(args)
      local term_id = M.get_terminal_id(args.buf)
      if term_id then
        M.last_active_terminal_id = term_id
        -- Ensure line numbers are enabled when entering terminal buffer
        vim.api.nvim_set_option_value('number', true, { win = 0 })
        vim.api.nvim_set_option_value('relativenumber', false, { win = 0 })
      end
    end,
  })

  -- Clean up closed terminals
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    pattern = "term://*",
    callback = function(args)
      local term_id = M.get_terminal_id(args.buf)
      if term_id then
        vim.defer_fn(function()
          -- Check if buffer is really gone
          if not vim.api.nvim_buf_is_valid(args.buf) then
            M.unregister_terminal(term_id)
          end
        end, 100)
      end
    end,
  })
end

return M

