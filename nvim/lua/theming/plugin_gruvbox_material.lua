local M = {}
M.setup = function()
    --[[ local config = require("theming.configuration").get({
        style = "dark",
        transparent = false,
    }) ]]

    if vim.fn.has("termguicolors") == 1 then
      vim.go.t_8f = "[[38;2;%lu;%lu;%lum"
      vim.go.t_8b = "[[48;2;%lu;%lu;%lum"
      vim.opt.termguicolors = true
    end

    vim.g.gruvbox_material_enable_italic = 0
    vim.g.gruvbox_material_disable_italic_comment = 1
    vim.g.gruvbox_material_sign_column_background = 'none'
    vim.g.gruvbox_material_cursor = 'green'
    -- vim.g.gruvbox_material_transparent_background = 1
    -- vim.g.gruvbox_material_visual = 'reverse'
    vim.cmd([[color gruvbox-material]])
end

return M
