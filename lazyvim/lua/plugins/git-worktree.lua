return {
  "git-worktree",
  dir = vim.fn.stdpath("config") .. "/lua/user/git-worktree",
  lazy = false,
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("user.git-worktree").setup()
  end,
  keys = {
    { "<leader>gwc", "<cmd>GitWorktreeCreate<cr>", desc = "Create Git Worktree" },
    { "<leader>gws", "<cmd>GitWorktreeSwitch<cr>", desc = "Switch Git Worktree" },
  },
}

