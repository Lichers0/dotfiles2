local M = {}
function M.setup()
  vim.g.ctrlsf_ackprg = 'rg'
  vim.g.ctrls_auto_preview = 1
  vim.g.ctrlsf_search_mode = 'async'
  vim.g.ctrlsf_regex_pattern = 1
end

return M
