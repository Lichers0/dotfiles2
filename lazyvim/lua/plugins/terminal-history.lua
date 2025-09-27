return {
  {
    "terminal-history",
    dir = vim.fn.stdpath("config") .. "/lua/terminal-history",
    lazy = false, -- Load immediately
    priority = 1000, -- Load early
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("terminal-history").setup({
        enabled = true,
        per_terminal = true,
        max_entries_per_terminal = 500,

        storage = {
          path = vim.fn.stdpath("data") .. "/terminal-history",
          persist_after_close = true,
          cleanup_after_days = 7,
        },

        filters = {
          ignore_commands = { "clear", "exit", "ls", "pwd" },
          min_command_length = 2,
          max_output_size = 1024 * 256, -- 256KB
        },

        ui = {
          show_terminal_id = true,
          date_format = "%H:%M:%S",
          telescope = {
            theme = "dropdown",
            previewer = true,
          },
        },

        keymaps = {
          open_history = "<leader>th",
          open_history_in_terminal = "<C-t>", -- Just Ctrl-T in terminal mode
          list_terminals = "<leader>tH",
          open_in_buffer = "<CR>",
          copy_command = "<C-y>",
          delete_entry = "<C-d>",
          delete_terminal_lines = "<C-l>", -- Ctrl-L in terminal mode to delete last 10 lines
        },
      })

      -- Register Telescope extension
      require("terminal-history.telescope").setup()
    end,
  },
}
