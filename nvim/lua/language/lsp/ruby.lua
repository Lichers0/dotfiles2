local M = {}
function M.setup(capabilities, on_attach)
    if not require("language.lsp.which").path_exists("solargraph") then
        return
    end

    require("lspconfig").solargraph.setup({
        capabilities = capabilities,
    })
end

return M