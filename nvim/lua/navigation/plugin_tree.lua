local tree_cb = require("nvim-tree.config").nvim_tree_callback

local mappings = {}
for key, value in pairs(require("mappings").explorer) do
    table.insert(mappings, { key = key, cb = tree_cb(value) })
end

for key, value in pairs(require("mappings").explorer_nocallback) do
    table.insert(mappings, { key = key, cb = value })
end

require("nvim-tree").setup({
  renderer = {
    indent_markers = {
      enable = true,
      icons = {
        corner = "└",
        edge = "│",
        none = " ",
      },
    },
    icons = {
      show = {
        folder_arrow = false,
      },
      glyphs = {
        default = '',
        symlink = '',
        git = {
          unstaged = "",
          staged = "",
          unmerged = "",
          renamed = "➜",
          untracked = ""
        }
      },
    },
  },
  update_focused_file = {
      enable = true,
  },
  view = {
      mappings = {
          list = mappings,
      },
  },
})




