local M = {}

M.options = {
  -- Basic settings
  enabled = true,
  per_terminal = true,
  max_entries_per_terminal = 500,

  -- Storage settings
  storage = {
    path = vim.fn.stdpath("data") .. "/terminal-history",
    persist_after_close = true,
    cleanup_after_days = 7,
  },

  -- Filtering
  filters = {
    ignore_commands = { "clear", "exit" },
    min_command_length = 2,
    max_output_size = 1024 * 512, -- 512KB
  },

  -- UI settings
  ui = {
    show_terminal_id = true,
    date_format = "%H:%M:%S",
    reuse_output_window = true, -- Reuse window for output by default
    telescope = {
      theme = "dropdown",
      previewer = true,
    },
  },

  -- Keymaps
  keymaps = {
    open_history = "<leader>th",
    open_history_in_terminal = "<C-t>", -- For terminal mode (just Ctrl-T)
    list_terminals = "<leader>tH",
    open_in_buffer = "<CR>",
    copy_command = "<C-y>",
    delete_entry = "<C-d>",
  },
}

-- Setup function to merge user config
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M

