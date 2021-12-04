local M = {}
M.setup = function()
    local config = require("theming.configuration").get({
        style = "dark",
        transparent = false,
    })

    require("github-theme").setup({
        sidebars = config.sidebars,
        theme_style = config.style,
        transparent = config.transparent,
    })
end

return M
