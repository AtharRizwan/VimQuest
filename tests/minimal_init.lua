-- Loads only VimQuest from this repo, with the editor options the game is designed around
local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
vim.opt.rtp:prepend(root)
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.confirm = true
vim.o.swapfile = false
dofile(vim.fs.joinpath(root, 'lua', 'custom', 'plugins', 'vimquest.lua'))
