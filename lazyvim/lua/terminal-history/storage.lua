local M = {}

-- Get storage directory
function M.get_storage_dir()
  local dir = vim.fn.stdpath("data") .. "/terminal-history"
  vim.fn.mkdir(dir, "p")
  return dir
end

-- Get history file path for terminal
function M.get_history_file(term_id)
  return M.get_storage_dir() .. "/terminal_" .. term_id .. ".json"
end

-- Get sessions metadata file
function M.get_sessions_file()
  return M.get_storage_dir() .. "/sessions.json"
end

-- Read JSON file
function M.read_json(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local content = vim.fn.readfile(filepath)
  if #content == 0 then
    return nil
  end

  local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
  if ok then
    return data
  end
  return nil
end

-- Write JSON file
function M.write_json(filepath, data)
  local ok, json = pcall(vim.json.encode, data)
  if not ok then
    vim.notify("Failed to encode JSON: " .. json, vim.log.levels.ERROR)
    return false
  end

  -- Pretty print JSON
  local pretty = vim.fn.system("echo " .. vim.fn.shellescape(json) .. " | python3 -m json.tool 2>/dev/null")
  if vim.v.shell_error == 0 and pretty ~= "" then
    json = pretty
  end

  vim.fn.writefile(vim.split(json, "\n"), filepath)
  return true
end

-- Load terminal history
function M.load_history(term_id)
  local filepath = M.get_history_file(term_id)
  local data = M.read_json(filepath)

  if data and data.history then
    return data.history
  end
  return {}
end

-- Save complete terminal history
function M.save_history(term_id, history)
  local filepath = M.get_history_file(term_id)
  local data = {
    terminal_id = term_id,
    last_updated = os.time(),
    history = history,
  }
  return M.write_json(filepath, data)
end

-- Append single entry to history
function M.append_to_history(term_id, entry)
  local filepath = M.get_history_file(term_id)
  local data = M.read_json(filepath) or {
    terminal_id = term_id,
    history = {},
  }

  table.insert(data.history, entry)
  data.last_updated = os.time()

  -- Limit history size
  local config = require("terminal-history.config")
  local max_entries = config.options.max_entries_per_terminal
  if #data.history > max_entries then
    -- Remove oldest entries
    local to_remove = #data.history - max_entries
    for i = 1, to_remove do
      table.remove(data.history, 1)
    end
  end

  return M.write_json(filepath, data)
end

-- Clear terminal history
function M.clear_history(term_id)
  local filepath = M.get_history_file(term_id)
  if vim.fn.filereadable(filepath) == 1 then
    vim.fn.delete(filepath)
  end

  -- Update sessions metadata
  M.update_session_metadata(term_id, { cleared = true, cleared_at = os.time() })
end

-- Save terminal session metadata
function M.save_terminal_session(term_id, terminal_data)
  -- Save final history
  if terminal_data.history and #terminal_data.history > 0 then
    M.save_history(term_id, terminal_data.history)
  end

  -- Update sessions metadata
  local metadata = {
    terminal_id = term_id,
    name = terminal_data.name,
    start_time = terminal_data.start_time,
    end_time = os.time(),
    cwd = terminal_data.cwd,
    history_count = #(terminal_data.history or {}),
  }

  M.update_session_metadata(term_id, metadata)
end

-- Update sessions metadata
function M.update_session_metadata(term_id, session_info)
  local filepath = M.get_sessions_file()
  local sessions = M.read_json(filepath) or {}

  sessions[tostring(term_id)] = session_info
  sessions[tostring(term_id)].last_updated = os.time()

  M.write_json(filepath, sessions)
end

-- Get all sessions metadata
function M.get_all_sessions()
  local filepath = M.get_sessions_file()
  return M.read_json(filepath) or {}
end

-- Clean old histories
function M.cleanup_old_histories(days)
  local config = require("terminal-history.config")
  days = days or config.options.storage.cleanup_after_days

  if days <= 0 then
    return
  end

  local cutoff_time = os.time() - (days * 24 * 60 * 60)
  local sessions = M.get_all_sessions()
  local cleaned = 0

  for term_id, session in pairs(sessions) do
    if session.last_updated and session.last_updated < cutoff_time then
      -- Delete history file
      local history_file = M.get_history_file(term_id)
      if vim.fn.filereadable(history_file) == 1 then
        vim.fn.delete(history_file)
        cleaned = cleaned + 1
      end
      -- Remove from sessions
      sessions[term_id] = nil
    end
  end

  if cleaned > 0 then
    M.write_json(M.get_sessions_file(), sessions)
    vim.notify(string.format("Cleaned %d old terminal histories", cleaned), vim.log.levels.INFO)
  end
end

-- Export history to file
function M.export_history(term_id, output_file, format)
  format = format or "json"
  local history = M.load_history(term_id)

  if not history or #history == 0 then
    vim.notify("No history to export", vim.log.levels.WARN)
    return false
  end

  if format == "json" then
    return M.write_json(output_file, history)
  elseif format == "text" then
    local lines = {}
    for _, entry in ipairs(history) do
      table.insert(lines, string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S", entry.timestamp), entry.command))
      if entry.output and entry.output ~= "" then
        table.insert(lines, entry.output)
      end
      table.insert(lines, "")
    end
    vim.fn.writefile(lines, output_file)
    return true
  end

  return false
end

return M
