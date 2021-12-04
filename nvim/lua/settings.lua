local M = {}

function M.theme()
    return {
        theme = "material",
        -- theme = 'github',
        -- style = dark/dark_default/dimmed/light/light_default
        -- transparent = false,

        -- theme = 'material'
        -- style = darker, lighter, oceanic, palenight, deep ocean
        -- transparent = false,

        -- theme = 'onedark',

        -- theme = 'tokyonight',
        -- style = 'storm', 'night', or 'day'
        -- transparent = false,
    }
end

function M.setup()
    vim.g.mapleader = " "

    local options = require("nvim.options")
    local option, buffer, window = options.scope.option, options.scope.buffer, options.scope.window

    -- vim.cmd([[set fillchars=eob:\ ,]])
    -- vim.cmd([[set shortmess+=c]])
    -- vim.cmd([[set undofile]]) ]]

    -- options
    if not M.theme().transparent then
        -- options.set(option, "cursorline", true)
    end

    -- options.set(option, "hidden", true)
    -- options.set(option, "ignorecase", true)
    -- options.set(option, "mouse", "a")
    -- options.set(option, "showmode", false[)
    -- options.set(option, "smartcase", true)
    -- options.set(option, "splitbelow", true)
    -- options.set(option, "splitright", true)
    options.set(option, "termguicolors", true)

    -- options.set(window, "number", true)
    -- options.set(window, "relativenumber", true)
    options.set(window, "signcolumn", "yes:2")

    -- options.set(buffer, "expandtab", true)
    -- options.set(buffer, "shiftwidth", 4)
    -- options.set(buffer, "softtabstop", 4)
    -- options.set(buffer, "tabstop", 4)

    vim.opt.shell = '/bin/bash'
    -- Global
    vim.opt.fillchars = { vert = ' ' }
    vim.opt.showtabline = 2
    vim.opt.scrolloff = 5
    vim.opt.mouse = 'a'
    vim.opt.backupcopy = 'yes'
    vim.opt.undolevels = 1000
    vim.opt.shortmess:append { c = true, S = true }
    vim.opt.showmode = false
    vim.opt.hidden = true
    vim.opt.splitright = true
    vim.opt.splitbelow = true
    vim.opt.wrapscan = true
    vim.opt.backup = false
    vim.opt.writebackup = false
    vim.opt.showcmd = true
    vim.opt.showmatch = true
    vim.opt.ignorecase = true
    vim.opt.hlsearch = true
    vim.opt.smartcase = true
    vim.opt.errorbells = false
    vim.opt.joinspaces = false
    vim.opt.title = true
    vim.opt.lazyredraw = true
    vim.opt.encoding = 'UTF-8'
    vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
    vim.opt.clipboard = 'unnamedplus'
    vim.opt.listchars = { tab = ">>>", trail = "·", precedes = "←", extends = "→",eol = "↲", nbsp = "␣" }
    -- Buffer
    vim.opt.fileformat = 'unix'
    vim.opt.tabstop = 2
    vim.opt.spelllang = 'it'
    vim.opt.softtabstop = 2
    vim.opt.swapfile = false
    vim.opt.undofile = false
    vim.opt.expandtab = true
    vim.opt.shiftwidth = 2
    -- Window
    vim.opt.number = true
    vim.opt.colorcolumn = "+1"
    vim.opt.foldmethod = 'indent'
    vim.opt.foldlevel = 1
    vim.opt.list = false
    vim.opt.foldnestmax = 10
    -- vim.opt.signcolumn = 'yes'
    vim.opt.relativenumber = true
    vim.opt.foldenable = false
    vim.opt.cursorline = true

    vim.cmd[[autocmd BufReadPost * lua goto_last_pos()]]
    function goto_last_pos()
      local last_pos = vim.fn.line("'\"")
      if last_pos > 0 and last_pos <= vim.fn.line("$") then
        vim.api.nvim_win_set_cursor(0, {last_pos, 0})
      end
    end

    vim.cmd 'au TextYankPost * silent! lua vim.highlight.on_yank()'
    end

return M
