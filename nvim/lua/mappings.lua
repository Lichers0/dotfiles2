local keymaps = require("nvim.keymaps")

local mappings = {}

local function windows()
    keymaps.register("n", {
        ["<C-w>x"] = [[<C-w>s]],
    })
end

local function insert_mode()
    keymaps.register("i", {
        ["kj"] = [[<ESC>]],
        ["jk"] = [[<ESC>]],
    })
end

local function zen()
    keymaps.register("n", {
        ["<leader>zm"] = [[<cmd>ZenMode<cr>]],
    })
end

local function functions()
    keymaps.register("n", {
        ["<C-a>"] = [[<cmd>TodoTrouble<cr>]],
        ["<leader>ntt"] = [[<cmd>NvimTreeToggle<cr>]],
        ["<leader>ntf"] = [[<cmd>lua require'sidebar'.explorer()<cr>]],
        ["<leader>tg"] = [[<cmd>lua require'telescope.builtin'.live_grep()<cr>]],
        ["<leader>tb"] = [[<cmd>lua require'telescope.builtin'.buffers()<cr>]],
        ["<leader>tf"] = [[<cmd>lua require'telescope.builtin'.current_buffer_fuzzy_find()<cr>]],
        ["<leader>tld"] = [[<cmd>lua require'telescope.builtin'.lsp_document_diagnostics()<cr>]],
        ["<leader>ns"] = [[<cmd>lua require'navigation.search'.git_or_local()<cr>]],
        ["<C-f><C-h>"] = [[<cmd>lua require'telescope.builtin'.oldfiles()<cr>]],
        ["<C-f><C-l>"] = [[<cmd>lua require'telescope.builtin'.lsp_document_symbols()<cr>]],
        ["<C-f><C-s>"] = [[<cmd>lua require'telescope.builtin'.lsp_workspace_symbols()<cr>]],
        ["<leader>sb"] = [[<cmd>lua require'sidebar'.symbols()<cr>]],
        ["<C-q>"] = [[<cmd>LspTrouble quickfix<cr>]],
        ["<C-x>"] = [[<cmd>LspTrouble lsp_workspace_diagnostics<cr>]],
    })
end

mappings.functions_terminal = "<C-t>"

local function buffer()
    keymaps.register("n", {
        ["<C-b><C-n>"] = [[<cmd>enew<cr>]],
        ["<C-b><C-s>"] = [[<cmd>w<cr>]],
        ["<C-c>"] = [[<cmd>lua require'bufdelete'.bufdelete()<cr>]],
        ["<C-n>"] = [[<cmd>BufferLineCycleNext<cr>]],
        ["<C-p>"] = [[<cmd>BufferLineCyclePrev<cr>]],
        ["<leader>bda"] = [[<cmd>BufferCloseAllButCurrent<cr>]],

        ["<leader>b"] = [[<cmd>BufferLinePick<cr>]],

        ["+"] = [[<C-a>]],
        ["-"] = [[<C-x>]],
    })
    keymaps.register("x", {
        ["+"] = [[g<C-a>]],
        ["-"] = [[g<C-x>]],
    })
end

-- editor
mappings.editor_on_text = {
    ["<leader>lft"] = [[<cmd>lua vim.lsp.buf.formatting()<cr>]],
    ["<leader>ldc"] = [[<cmd>lua vim.lsp.buf.declaration()<cr>]],
    ["<leader>lhv"] = [[<cmd>lua vim.lsp.buf.hover()<cr>]],
    ["<leader>lrf"] = [[<cmd>lua vim.lsp.buf.references()<cr>]],
    ["<leader>lds"] = [[<cmd>lua vim.lsp.buf.document_symbol()<cr>]],
    ["<leader>ldf"] = [[<cmd>lua vim.lsp.buf.definition()<cr>]],
    ["<leader>lgk"] = [[<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>]],
    ["<leader>lgn"] = [[<cmd>lua vim.lsp.diagnostic.goto_next()<cr>]],
    ["<leader>lca"] = [[<cmd>lua vim.lsp.diagnostic.code_action()<cr>]],
    ["<leader>lim"] = [[<cmd>lua vim.lsp.buf.implementation()<cr>]],
    ["<leader>lsh"] = [[<cmd>lua vim.lsp.buf.signature_help()<cr>]],
    ["<leader>lrn"] = [[<cmd>lua vim.lsp.buf.rename()<cr>]],
    -- ["tdf"] = [[<cmd>lua require'telescope.builtin'.lsp_definitions()<cr>]],
    -- ["trf"] = [[<cmd>lua require'telescope.builtin'.lsp_references()<cr>]],
    -- ["tca"] = [[<cmd>lua require'telescope.builtin'.lsp_code_actions()<cr>]],
    -- ["sdk"] = [[<cmd>lua require'lspsaga.diagnostic'.lsp_jump_diagnostic_prev()<cr>]],
    -- ["sdj"] = [[<cmd>lua require'lspsaga.diagnostic'.lsp_jump_diagnostic_next()<cr>]],
}

local function editor_motion()
    keymaps.register("n", {
        ["<leader>jc"] = [[<cmd>HopChar1<cr>]],
        ["<leader>jl"] = [[<cmd>HopLine<cr>]],
        ["<leader>jw"] = [[<cmd>HopWord<cr>]],
        ["<leader>jp"] = [[<cmd>HopPattern<cr>]],
    })
end

mappings.editor_motion_textsubjects = {
    init_selection = "<CR>",
    scope_incremental = "<CR>",
    node_incremental = "<C-k>",
    node_decremental = "<C-j>",
}

mappings.explorer = {
    ["l"] = "edit",
    ["h"] = "close_node",
    ["r"] = "full_rename",
    ["m"] = "cut",
    ["d"] = "remove",
    ["y"] = "copy",
}

mappings.explorer_nocallback = {
    ["<C-c>"] = [[<cmd>lua require'sidebar'.close()<cr>]],
    ["q"] = [[<cmd>lua require'sidebar'.close()<cr>]],
}

mappings.diagnostics = {
    ["close"] = "<C-c>",
    ["cancel"] = "<C-k>",
    ["refresh"] = "r",
    ["jump"] = "<cr>",
    ["hover"] = "K",
    ["toggle_fold"] = "<space>",
    ["previous"] = "<C-p>",
    ["next"] = "<C-n>",
}

mappings.search = function(actions)
    return {
        ["<C-q>"] = actions.send_to_qflist,
    }
end

local function terminal()
    keymaps.register("t", {
        ["<C-k>"] = [[<C-\><C-n><C-w><C-k>]],
        ["<C-j>"] = [[<cmd>ToggleTerm<cr>]],
    })
end

local function search()
    keymaps.register("n", {
        ["<Leader>sfp"] = [[<Plug>CtrlSFPrompt]],
        ["<Leader>sft"] = [[<cmd>CtrlSFToggle<cr>]],
      }, {
        noremap = false, silent = false 
      }
    )
    keymaps.register("n", {
        ["//"] = [[<cmd>nohlsearch<cr>]],
      }, {
        noremap = false, silent = true 
      }
    )
    keymaps.register("n", {
        ["<leader>hl"] = [[<cmd>set hlsearch! hlsearch?<cr>]],
      }, {
        noremap = true, silent = false 
      }
    )
    keymaps.register("n", {
        ["n"] = [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<cr>]],
        ["N"] = [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<crCR>]],
      }, {
        noremap = true, silent = true
      }
    )
    keymaps.register("n", {
        ["*"] = [[*<Cmd>lua require('hlslens').start()<CR>]],
        ["#"] = [[#<Cmd>lua require('hlslens').start()<CR>]],
        ["g*"] = [[g*<Cmd>lua require('hlslens').start()<CR>]],
        ["g#"] = [[g#<Cmd>lua require('hlslens').start()<CR>]],
      }, {
        noremap = true
      }
    )
end

mappings.setup = function()
    windows()
    zen()
    functions()
    buffer()
    editor_motion()
    terminal()
    insert_mode()
    search()
end

return mappings
