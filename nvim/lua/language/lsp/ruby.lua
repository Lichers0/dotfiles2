local M = {}
function M.setup(capabilities, on_attach)
    if not require("language.lsp.which").path_exists("solargraph") then
        return
    end

    local nvim_lsp = require("lspconfig")
    nvim_lsp.solargraph.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        filetypes = {"ruby", "rakefile"},
        root_dir = nvim_lsp.util.root_pattern("Gemfile", ".git", "."),
        settings = {
            solargraph = {
                autoformat = true,
                completion = true,
                diagnostic = true,
                folding = true,
                references = true,
                rename = true,
                symbols = true
            }
        }
    })
end

return M
