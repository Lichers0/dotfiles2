-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>bn", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
  print("Copied: " .. vim.fn.expand("%:p"))
end, { desc = "Copy file path" })

vim.keymap.set("n", "<leader>bm", function()
  vim.fn.setreg("+", vim.fn.expand("%"))
  print("Copied: " .. vim.fn.expand("%"))
end, { desc = "Copy relative path" })
