-- Loaded by the Docker image before the config (see Dockerfile).
-- A container has no clipboard tool, so copies go to your real clipboard through the terminal (OSC 52) and pastes
-- come from Neovim's own register. Reading the clipboard over OSC 52 would make many terminals ask permission on every p.
local osc52 = require 'vim.ui.clipboard.osc52'

local function paste() return { vim.fn.split(vim.fn.getreg '', '\n'), vim.fn.getregtype '' } end

vim.g.clipboard = {
  name = 'OSC 52 (copy only)',
  copy = { ['+'] = osc52.copy '+', ['*'] = osc52.copy '*' },
  paste = { ['+'] = paste, ['*'] = paste },
}
