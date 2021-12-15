local actions = require("telescope.actions")
local mapping = require("mappings")

local M = {}
function M.setup()
    require("telescope").setup({
        defaults = {
            extensions = {
                fzf = {
                    fuzzy = true,
                    override_generic_sorter = true,
                    override_file_sorter = true,
                    case_mode = "smart_case",
                },
            },
            mappings = {
              i = {
                ["<C-j>"]   = actions.move_selection_next,
                ["<C-k>"]   = actions.move_selection_previous,
                ["<ESC>"]   = actions.close,
                ["<C-c>"]   = actions.close,
              },
            },
            layout_strategy = "flex",
        },
    })

    require("telescope").load_extension("fzf")
end

return M
