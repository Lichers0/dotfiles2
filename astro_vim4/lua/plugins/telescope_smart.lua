return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    {
      "<leader>fs",
      function()
        require("user.telescope_smart_search").smart_search()
      end,
      desc = "Smart Search (files or grep)",
    },
  },
}
