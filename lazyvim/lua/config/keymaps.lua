-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>b.", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
  print("Copied: " .. vim.fn.expand("%:p"))
end, { desc = "Copy full file path" })

vim.keymap.set("n", "<leader>b,", function()
  vim.fn.setreg("+", vim.fn.getcwd())
  print("Copied: " .. vim.fn.getcwd())
end, { desc = "Copy root path" })

local function copy_path_with_lines()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local current_file = vim.fn.expand("%:p")
  local relative_path = vim.fn.fnamemodify(current_file, ":~:.")
  local result

  -- Проверить, есть ли выделение
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    if start_line == end_line then
      result = "@" .. relative_path .. "#L" .. start_line
    else
      result = "@" .. relative_path .. "#L" .. start_line .. "-" .. end_line
    end
  else
    local current_line = vim.fn.line(".")
    result = "@" .. relative_path .. "#L" .. current_line
  end

  vim.fn.setreg("+", result)
  print("Copied: " .. result)
end

vim.keymap.set("v", "<leader>bn", function()
  copy_path_with_lines()
end, { desc = "send select to clipboard" })

local function copy_full_path_with_lines()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local current_file = vim.fn.expand("%:p")
  local relative_path = current_file
  local result

  -- Проверить, есть ли выделение
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    if start_line == end_line then
      result = "@" .. relative_path .. "#L" .. start_line
    else
      result = "@" .. relative_path .. "#L" .. start_line .. "-" .. end_line
    end
  else
    local current_line = vim.fn.line(".")
    result = "@" .. relative_path .. "#L" .. current_line
  end

  vim.fn.setreg("+", result)
  print("Copied: " .. result)
end

vim.keymap.set("v", "<leader>bm", function()
  copy_full_path_with_lines()
end, { desc = "send full select to clipboard" })
