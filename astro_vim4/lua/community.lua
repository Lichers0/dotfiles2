-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.git.blame-nvim"}, -- blame списком и переход на коммит
  { import = "astrocommunity.indent.mini-indentscope"}, -- ii, ai
  { import = "astrocommunity.motion.flash-nvim"}, -- прыгаем по триситеру и словам
  -- { import = "astrocommunity.motion.mini-surround"}, -- Удаляем - добавляем кавычки
  { import = "astrocommunity.motion.nvim-surround"}, -- Удаляем - добавляем кавычки
  { import = "astrocommunity.editing-support.dial-nvim" }, -- true -> false, && -> ||
  { import = "astrocommunity.editing-support.chatgpt-nvim" }, -- чат gpt

  -- import/override with your plugins folder
}
