-- Run by the Docker build and CI after the config loads: fails if a language server, parser or the game is missing.
-- bootstrap.lua keeps going when an install fails, so without this a broken image would still build.
local missing = {}

local package_for = require('mason-lspconfig').get_mappings().lspconfig_to_package
local registry = require 'mason-registry'
for _, config in ipairs(vim.lsp.get_configs { enabled = true }) do
  local pkg = package_for[config.name]
  if pkg and not registry.is_installed(pkg) then table.insert(missing, 'language server ' .. pkg) end
end

for _, lang in ipairs(vim.g.ts_parsers or {}) do
  if not vim.treesitter.language.add(lang) then table.insert(missing, 'parser ' .. lang) end
end

if vim.fn.exists ':VimQuest' ~= 2 then table.insert(missing, 'the :VimQuest command') end
if vim.v.errmsg ~= '' then table.insert(missing, 'a clean start (error: ' .. vim.v.errmsg .. ')') end

if #missing > 0 then
  io.stderr:write('Missing from the image:\n  ' .. table.concat(missing, '\n  ') .. '\n')
  vim.cmd 'cquit 1'
end
vim.cmd 'qa!'
