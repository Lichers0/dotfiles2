local keymaps = require("nvim.keymaps")
local mappings = require("mappings")

local function on_attach(client, bufnr)
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

    require("aerial").on_attach(client)

    require("lsp_signature").on_attach({
        bind = true,
        handler_opts = {
            border = "single",
        },
        hint_enable = false,
    })

    keymaps.register_bufnr(bufnr, "n", mappings.editor_on_text)
end

local m = {}
m.setup = function()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
        virtual_text = {
            prefix = "𥉉 ",
        },
    })

    require("language.lsp").setup(capabilities, on_attach)

    require("nvim-lsp-installer").on_server_ready(function(server)
        server:setup({})
        vim.cmd([[ do User LspAttachBuffers ]])
    end)
end

return m
