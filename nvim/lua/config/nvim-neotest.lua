return {
  setup = function(use)
    use({
      "nvim-neotest/neotest",
      requires = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "antoinemadec/FixCursorHold.nvim",
        "olimorris/neotest-rspec",
      },
      config = function()
        local neotest = require("neotest")

        neotest.setup({
          adapters = {
            require("neotest-rspec"),
          }
        })

        local api = vim.api

        api.nvim_set_keymap("n", "<leader>tt", "lua neotest.run.run()", { desc = "Run nearest test" })

        vim.keymap.set("n", "<leader>tf", function()
          neotest.run.run(vim.fn.expand("%"))
        end, { desc = "Run current file" })

        vim.keymap.set("n", "<leader>ta", function()
          neotest.run.attach()
        end, { desc = "Attach to nearest test" })

        vim.keymap.set("n", "<leader>ts", function()
          neotest.summary.toggle()
        end, { desc = "Toggle test summary view" })

        vim.keymap.set("n", "<leader>tl", function()
          neotest.run.run_last()
        end, { desc = "Rerun last test" })
      end
    })
  end,
}
