require("nvim-treesitter.configs").setup({
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = true,
    },
    indent = {
        enable = true,
    },
    incremental_selection = {
        enable = true,
        keymaps = require("mappings").editor_motion_textsubjects,
    },

    -- third party
    rainbow = {
        enable = true,
    },
})
