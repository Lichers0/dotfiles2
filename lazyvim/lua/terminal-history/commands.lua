local M = {}

-- Setup user commands
function M.setup()
  -- Show history for current or specified terminal
  vim.api.nvim_create_user_command("TerminalHistory", function(opts)
    local term_id = nil
    if opts.args and opts.args ~= "" then
      term_id = tonumber(opts.args)
    end
    require("terminal-history.ui").show_terminal_history(term_id)
  end, { nargs = "?", desc = "Show terminal history" })

  -- List all terminals
  vim.api.nvim_create_user_command("TerminalHistoryList", function()
    require("terminal-history.ui").list_all_terminals()
  end, { desc = "List all terminal sessions" })

  -- Show current terminal history explicitly
  vim.api.nvim_create_user_command("TerminalHistoryCurrent", function()
    local core = require("terminal-history.core")
    local term_id = core.get_active_terminal_id()
    if term_id then
      require("terminal-history.ui").show_terminal_history(term_id)
    else
      vim.notify("No active terminal", vim.log.levels.WARN)
    end
  end, { desc = "Show current terminal history" })

  -- Clear history
  vim.api.nvim_create_user_command("TerminalHistoryClear", function(opts)
    local core = require("terminal-history.core")
    local term_id = nil

    if opts.args and opts.args ~= "" then
      term_id = tonumber(opts.args)
    else
      term_id = core.get_active_terminal_id()
    end

    if term_id then
      core.clear_history(term_id)
      vim.notify("History cleared for terminal #" .. term_id, vim.log.levels.INFO)
    else
      vim.notify("No terminal specified", vim.log.levels.WARN)
    end
  end, { nargs = "?", desc = "Clear terminal history" })

  -- Delete last N lines from terminal
  vim.api.nvim_create_user_command("TerminalDeleteLines", function(opts)
    local core = require("terminal-history.core")
    local count = tonumber(opts.args) or 10
    core.delete_last_lines(count)
  end, { nargs = "?", desc = "Delete last N lines from terminal (default: 10)" })

  -- Toggle tracking
  vim.api.nvim_create_user_command("TerminalHistoryToggle", function()
    local core = require("terminal-history.core")
    local enabled = core.toggle_tracking()

    if enabled ~= nil then
      local status = enabled and "enabled" or "disabled"
      vim.notify("Terminal history tracking " .. status, vim.log.levels.INFO)
    else
      vim.notify("No active terminal", vim.log.levels.WARN)
    end
  end, { desc = "Toggle history tracking for current terminal" })

  -- Export history
  vim.api.nvim_create_user_command("TerminalHistoryExport", function(opts)
    local args = vim.split(opts.args, " ")
    local term_id = tonumber(args[1])
    local filepath = args[2]

    if not term_id or not filepath then
      vim.notify("Usage: TerminalHistoryExport <terminal_id> <filepath>", vim.log.levels.ERROR)
      return
    end

    local storage = require("terminal-history.storage")
    if storage.export_history(term_id, filepath, "text") then
      vim.notify("History exported to " .. filepath, vim.log.levels.INFO)
    else
      vim.notify("Failed to export history", vim.log.levels.ERROR)
    end
  end, { nargs = "+", desc = "Export terminal history to file" })

  -- Clean old histories
  vim.api.nvim_create_user_command("TerminalHistoryCleanup", function()
    local storage = require("terminal-history.storage")
    storage.cleanup_old_histories()
  end, { desc = "Clean old terminal histories" })

  -- Manual capture current line
  vim.api.nvim_create_user_command("TerminalHistoryCapture", function()
    local capture_aggressive = require("terminal-history.capture-aggressive")
    capture_aggressive.capture_current_line()
  end, { desc = "Manually capture current line as command" })

  -- Open history in Telescope
  vim.api.nvim_create_user_command("TerminalHistoryTelescope", function(opts)
    local term_id = nil
    if opts.args and opts.args ~= "" then
      term_id = tonumber(opts.args)
    end
    require("terminal-history.telescope").terminal_history_picker({ terminal_id = term_id })
  end, { nargs = "?", desc = "Show terminal history in Telescope" })

  -- Toggle debug mode
  vim.api.nvim_create_user_command("TerminalHistoryDebug", function(opts)
    local debug = require("terminal-history.debug")

    if opts.args == "show" then
      debug.show()
      return
    elseif opts.args == "clear" then
      debug.clear()
      return
    end

    local enabled = opts.args == "on" or opts.args == "1" or opts.args == "true"
    require("terminal-history.capture").set_debug(enabled)
    require("terminal-history.capture-alt").debug = enabled
    debug.set_enabled(enabled)

    local status = enabled and "enabled" or "disabled"
    vim.notify("Terminal history debug mode " .. status, vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "show", "clear" }
    end,
    desc = "Debug mode for terminal history (on/off/show/clear)",
  })
end

return M
