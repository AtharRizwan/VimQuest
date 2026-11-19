-- Run by install.sh after the config loads: waits for language servers and parsers, then quits
local function step(msg) io.stdout:write('  ' .. msg .. '\n') end

step 'Installing language servers and formatters (Mason)...'
pcall(vim.cmd, 'MasonToolsInstallSync')

local ok, ts = pcall(require, 'nvim-treesitter')
if ok and vim.g.ts_parsers then
  step 'Compiling syntax parsers (Treesitter)...'
  pcall(function() ts.install(vim.g.ts_parsers):wait(900000) end)
end

step 'Done.'
vim.cmd 'qa!'
