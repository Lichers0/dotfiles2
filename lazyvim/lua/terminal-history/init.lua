local M = {}

M.initialized = false

-- Setup function
function M.setup(opts)
  if M.initialized then
    return
  end

  -- Setup configuration
  local config = require("terminal-history.config")
  config.setup(opts)

  -- Check if enabled
  if not config.options.enabled then
    return
  end

  -- Setup core autocmds
  local core = require("terminal-history.core")
  core.setup_autocmds()

  -- Setup user commands
  local commands = require("terminal-history.commands")
  commands.setup()

  -- Setup keymaps
  M.setup_keymaps()

  -- Schedule cleanup of old histories
  vim.defer_fn(function()
    local storage = require("terminal-history.storage")
    storage.cleanup_old_histories()
  end, 5000)

  M.initialized = true
end

-- Setup global keymaps
function M.setup_keymaps()
  local config = require("terminal-history.config")
  local keymaps = config.options.keymaps

  -- Normal mode keymaps
  if keymaps.open_history and keymaps.open_history ~= "" then
    vim.keymap.set("n", keymaps.open_history, ":TerminalHistory<CR>", { desc = "Open terminal history" })
  end

  if keymaps.list_terminals and keymaps.list_terminals ~= "" then
    vim.keymap.set("n", keymaps.list_terminals, ":TerminalHistoryList<CR>", { desc = "List all terminals" })
  end

  -- Terminal mode keymap for opening history in Telescope
  if keymaps.open_history_in_terminal and keymaps.open_history_in_terminal ~= "" then
    vim.keymap.set(
      "t",
      keymaps.open_history_in_terminal,
      "<C-\\><C-n>:TerminalHistoryTelescope<CR>",
      { desc = "Open terminal history in Telescope" }
    )
    -- Debug log to confirm mapping was set
    vim.notify("Terminal history: Ctrl-T mapped for terminal mode (Telescope)", vim.log.levels.INFO)
  end
end

-- Public API functions
M.show_history = function(term_id)
  require("terminal-history.ui").show_terminal_history(term_id)
end

M.list_terminals = function()
  require("terminal-history.ui").list_all_terminals()
end

M.clear_history = function(term_id)
  require("terminal-history.core").clear_history(term_id)
end

M.toggle_tracking = function(term_id)
  return require("terminal-history.core").toggle_tracking(term_id)
end

M.export_history = function(term_id, filepath, format)
  return require("terminal-history.storage").export_history(term_id, filepath, format)
end

M.telescope = function(term_id)
  require("terminal-history.telescope").terminal_history_picker({ terminal_id = term_id })
end

return M

