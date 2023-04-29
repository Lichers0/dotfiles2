local M = {}
M.setup = function()
    require("bufferline").setup({
        options = {
            close_command = function(bufnum)
                require("bufdelete").bufdelete(bufnum, true)
            end,
            right_mouse_command = function(bufnum)
                require("bufdelete").bufdelete(bufnum, true)
            end,
            offsets = {
                { filetype = "NvimTree", text = "Explorer", text_align = "left" },
                { filetype = "aerial", text = "Symbols", text_align = "left" },
            },
            indicator = {
                icon = '▎', -- this should be omitted if indicator style is not 'icon'
                style = 'icon',
            },
            buffer_close_icon = '',
            modified_icon = '●',
            close_icon = '',
            left_trunc_marker = '',
            right_trunc_marker = '',
            show_buffer_close_icons = true,
        },
    })
end

return M
