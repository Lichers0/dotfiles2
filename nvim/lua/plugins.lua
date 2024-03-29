local function git(use)
    -- TODO: https://github.com/sindrets/diffview.nvim
    -- TODO: neogit
    use({
        "lewis6991/gitsigns.nvim",
        config = function()
            require("git.plugin_gitsigns")
        end,
    })
end

local function language(use)
    use({
        "hrsh7th/nvim-cmp",
        config = function()
            require("language.plugin_cmp").setup()
        end,
    })
    use("rafamadriz/friendly-snippets")
    use({
        "b3nj5m1n/kommentary",
        config = function()
            require("kommentary.config")
        end,
    })
    use({
        "windwp/nvim-autopairs",
        config = function()
            require("language.plugin_autopairs").setup()
        end,
        after = "nvim-cmp",
    })
    use("onsails/lspkind-nvim")
    use({
        "L3MON4D3/LuaSnip",
        config = function()
            require("language.plugin_luasnip").setup()
        end,
    })
    use("saadparwaiz1/cmp_luasnip")
    use("hrsh7th/cmp-buffer")
    use("hrsh7th/cmp-nvim-lsp")
    use("hrsh7th/cmp-nvim-lua")
    use("hrsh7th/cmp-path")

    use({
        "stevearc/aerial.nvim",
        setup = function()
            require("language.plugin_aerial").setup()
        end,
    })
    use("ray-x/lsp_signature.nvim")
    use("neovim/nvim-lspconfig")
    use("jose-elias-alvarez/null-ls.nvim")
    use("williamboman/nvim-lsp-installer")
    use({
        "tami5/lspsaga.nvim",
        config = function()
            require("language.plugin_lspsaga").setup()
        end,
    })

    use({
        "folke/todo-comments.nvim",
        config = function()
            require("todo-comments").setup({})
        end,
    })
    use({
        "norcalli/nvim-colorizer.lua",
        config = function()
            require("language.plugin_colorizer")
        end,
    })
    use({
        "nvim-treesitter/nvim-treesitter",
        config = function()
            require("language.plugin_treesitter")
        end,
        run = ":TSUpdate",
    })
    use({
        "p00f/nvim-ts-rainbow",
        after = "nvim-treesitter",
    })
    use({
        "romgrk/nvim-treesitter-context",
        config = function()
            require("treesitter-context").setup({
                enable = true,
            })
        end,
        after = "nvim-treesitter",
    })
    -- use("vim-est/vim-test")
    --[[ use({
      "vim-est/vim-test",
      config = require("language.plugin_vimtest")
    }) ]]

    --[[ use({
      "tzachar/cmp-tabnine",
      config = function()
	      require('cmp_tabnine.config'):setup({
          max_lines = 1000;
          max_num_results = 20;
          sort = true;
          run_on_every_keystroke = true;
          snippet_placeholder = '..';
          ignored_file_types = {};
          show_prediction_strength = false;
          })
      end,
      run = "./install.sh",
      after = "hrsh7th/nvim-cmp",
    }) ]]
end

local function layout(use)
    use("famiu/bufdelete.nvim")
    use({
        "folke/which-key.nvim",
        config = function()
            require("which-key").setup()
        end,
    })
    use({
        "folke/zen-mode.nvim",
        config = function()
            require("zen-mode").setup({})
        end,
    })
end

local function motion(use)
    use({
        "phaazon/hop.nvim",
        as = "hop",
        config = function()
            require("hop").setup({})
        end,
    })
    -- a smooth scrolling neovim
    use({
        "karb94/neoscroll.nvim",
        config = function()
            require("motion.plugin_neoscroll")
        end,
    })
    -- peeks lines of the buffer in non-obtrusive way
    use({
        "nacro90/numb.nvim",
        config = function()
            require("numb").setup()
        end,
    })
    -- displays interactive vertical scrollbars
    use({
        "dstein64/nvim-scrollview",
        config = function()
            require("motion.plugin_scrollview")
        end,
    })
    -- An always-on highlight for a unique character in every word on a line to help you use f, F and family
    use("unblevable/quick-scope")
end

local function navigation(use)
    use({
        "akinsho/nvim-bufferline.lua",
        config = function()
            require("navigation.plugin_bufferline").setup()
        end,
    })
    use({
        "folke/lsp-trouble.nvim",
        config = function()
            require("navigation.plugin_trouble")
        end,
    })
    use({
        "kyazdani42/nvim-tree.lua",
        config = function()
            require("navigation.plugin_tree")
        end,
    })
    use({
        "nvim-telescope/telescope.nvim",
        config = function()
            require("navigation.plugin_telescope").setup()
        end,
    })
    use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
    use({
      "dyng/ctrlsf.vim",
      config = function()
        require("navigation/ctrlsf").setup()
      end,
    })
    use({
      "kevinhwang91/nvim-hlslens",
      config = function()
        require("navigation/hlslens").setup()
      end,
    })
end

local function startup(use)
    -- TODO: https://github.com/rmagatti/session-lens maybe with leader + s?
    --[[ use({
        "rmagatti/auto-session",
        config = function()
            require("startup.plugin_auto-session").setup()
        end,
    }) ]]
    use({
        "907th/vim-auto-save",
        config = function()
            vim.g.auto_save = 1
        end,
    })
end

local function status(use)
    use({
        "lukas-reineke/indent-blankline.nvim",
        config = function()
            require("status.plugin_indentblankline")
        end,
    })
    use({
        "nvim-lualine/lualine.nvim",
        config = function()
            require("status.plugin_lualine").setup()
        end,
    })
end

local function terminal(use)
    use({
        "akinsho/nvim-toggleterm.lua",
        config = function()
            require("terminal.plugin_toggleterm").setup()
        end,
    })
    use({
        "aserowy/tmux.nvim",
        config = function()
            require("terminal.plugin_tmux").setup()
        end,
    })
end

local function theming(use)
    use({
        "sainnhe/gruvbox-material",
        cond = function()
            return require("conditions").is_current_theme("gruvbox")
        end,
        config = function()
            require("theming.theme").setup("gruvbox")
        end,
    })
    use({
        "projekt0n/github-nvim-theme",
        cond = function()
            return require("conditions").is_current_theme("github")
        end,
        config = function()
            require("theming.theme").setup("github")
        end,
    })
    use({
        "marko-cerovac/material.nvim",
        cond = function()
            return require("conditions").is_current_theme("material")
        end,
        config = function()
            require("theming.theme").setup("material")
        end,
    })
    use({
        "ful1e5/onedark.nvim",
        cond = function()
            return require("conditions").is_current_theme("onedark")
        end,
        config = function()
            require("theming.theme").setup("onedark")
        end,
    })
    use({
        "folke/tokyonight.nvim",
        cond = function()
            return require("conditions").is_current_theme("tokyonight")
        end,
        config = function()
            require("theming.theme").setup("tokyonight")
        end,
    })
end

local function tpope(use)
  use 'tpope/vim-sensible'
  use 'tpope/vim-rails'
  use 'tpope/vim-abolish'
  use 'tpope/vim-surround'
  use 'tpope/vim-bundler'
  use 'tpope/vim-capslock'
  use 'tpope/vim-repeat'
  use 'tpope/vim-endwise'
  use 'tpope/vim-dispatch'
  use 'tpope/vim-dadbod'
  use 'tpope/vim-jdaddy'
  use 'tpope/vim-fugitive'
  use 'tpope/vim-commentary'
  -- '] ' ']e'
  use 'tpope/vim-unimpaired'
end

local function new_addition(use)
  use 'jessekelighine/vindent.vim'
  use 'mhartington/formatter.nvim'
  use 'mfussenegger/nvim-lint'
end

require("packer").startup(function(use)
    use("wbthomason/packer.nvim")

    -- dependencies
    use("rktjmp/lush.nvim")
    use("nvim-lua/plenary.nvim")
    use("nvim-lua/popup.nvim")
    use("kyazdani42/nvim-web-devicons")

    git(use)
    language(use)
    layout(use)
    motion(use)
    navigation(use)
    startup(use)
    status(use)
    terminal(use)
    theming(use)
    tpope(use)
    new_addition(use)

    require('config.nvim-notify').setup(use)
    require('config.nvim-neotest').setup(use)
end)
