local function generate_sources(null_ls)
    --[[ local helpers = require("null-ls.helpers")
    local methods = require("null-ls.methods") ]]

    --[[ local sources = {
        null_ls.builtins.formatting.prettier,
        null_ls.builtins.formatting.rustfmt,
        null_ls.builtins.formatting.stylua,
    } ]]
    local diagnostics = null_ls.builtins.diagnostics
    local formatting = null_ls.builtins.formatting

    local sources = {
      --[[ null_ls.builtins.diagnostics.hadolint,
      null_ls.builtins.diagnostics.jsonlint,
      null_ls.builtins.diagnostics.markdownlint,
      null_ls.builtins.diagnostics.write_good,
      null_ls.builtins.diagnostics.misspell,
      null_ls.builtins.diagnostics.yamllint,
      null_ls.builtins.diagnostics.erb_lint,
      null_ls.builtins.formatting.erb_lint,
      null_ls.builtins.diagnostics.haml_lint,
      null_ls.builtins.diagnostics.semgrep,
      null_ls.builtins.diagnostics.rubocop,
      null_ls.builtins.formatting.rubocop, ]]
      -- diagnostics.semgrep,
      diagnostics.rubocop,
      formatting.rubocop,
      --[[ diagnostics.standardrb,
      formatting.standardrb,
      null_ls.builtins.formatting.rufo,
      null_ls.builtins.formatting.pg_format, ]]
    }

    --[[ if require("language.lsp.which").path_exists("markdownlint") then
        table.insert(sources, null_ls.builtins.diagnostics.markdownlint)
    end ]]

    return sources
end

local M = {}
function M.setup(_, on_attach)
    local null_ls = require("null-ls")

    null_ls.setup({
        on_attach = on_attach,
        sources = generate_sources(null_ls),
        debug = true,
    })
end

return M
