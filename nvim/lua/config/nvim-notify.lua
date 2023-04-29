return {
  setup = function(use)
    use({
      "rcarriga/nvim-notify",
      config = function()
        require("notify").setup({ 
          render = "default",
          timeout = 100,
          top_down = false,
          stages = "fade",
        })
        vim.notify = require("notify")

        -- :Notifications
      end,
    })
  end,
}
