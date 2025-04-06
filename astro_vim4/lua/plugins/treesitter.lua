-- if tru then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    endwise = { enable = true },
    ensure_installed = {
      "lua",
      "vim",
      "go",
      "ruby",
      "sql"
      -- add more arguments for adding more treesitter parsers
    },
  },
}
