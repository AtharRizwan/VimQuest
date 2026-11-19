-- Productivity and UI extras

local gh = function(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'folke/snacks.nvim',
  gh 'folke/flash.nvim',
  gh 'folke/trouble.nvim',
  { src = gh 'akinsho/bufferline.nvim', version = vim.version.range '*' },
  gh 'windwp/nvim-ts-autotag',
  gh 'sphamba/smear-cursor.nvim',
}

-- Snacks: dashboard, lazygit, notifications, animated indent guides, smooth scroll, zen mode
require('snacks').setup {
  -- The default 'startup' section needs lazy.nvim, which kickstart doesn't use
  dashboard = {
    enabled = true,
    sections = {
      { section = 'header' },
      { section = 'keys', gap = 1, padding = 1 },
      { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
    },
  },
  notifier = { enabled = true },
  indent = { enabled = true },
  scroll = { enabled = true },
  words = { enabled = true },
  bigfile = { enabled = true },
  lazygit = { enabled = true },
  terminal = { enabled = true },
  zen = { enabled = true },
}
vim.keymap.set('n', '<leader>gg', function() Snacks.lazygit() end, { desc = 'Lazy[G]it' })
vim.keymap.set('n', '<leader>gb', function() Snacks.git.blame_line() end, { desc = '[G]it [B]lame line' })
vim.keymap.set('n', '<leader>gB', function() Snacks.gitbrowse() end, { desc = '[G]it open in [B]rowser' })
vim.keymap.set({ 'n', 't' }, '<C-\\>', function() Snacks.terminal() end, { desc = 'Toggle terminal' })
vim.keymap.set('n', '<leader>z', function() Snacks.zen() end, { desc = '[Z]en mode' })
vim.keymap.set('n', '<leader>n', function() Snacks.notifier.show_history() end, { desc = '[N]otification history' })
vim.keymap.set('n', '<leader>bd', function() Snacks.bufdelete() end, { desc = '[B]uffer [D]elete' })

-- Flash: press S, type 2 chars, then the label to jump anywhere on screen
require('flash').setup {}
vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').jump() end, { desc = 'Flash jump' })

-- Trouble: a nicer list of errors/warnings across the project
require('trouble').setup {}
vim.keymap.set('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Diagnostics (Trouble)' })
vim.keymap.set('n', '<leader>xb', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', { desc = '[B]uffer diagnostics' })

-- Bufferline: open files as tabs at the top
require('bufferline').setup {
  options = {
    diagnostics = 'nvim_lsp',
    offsets = { { filetype = 'neo-tree', text = 'Files', separator = true } },
  },
}
vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next buffer' })
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Previous buffer' })

-- Auto-close and auto-rename HTML/JSX tags
require('nvim-ts-autotag').setup {}

-- Animated cursor trail
require('smear_cursor').setup {}

require('which-key').add {
  { '<leader>g', group = '[G]it' },
  { '<leader>x', group = 'Diagnostics' },
  { '<leader>b', group = '[B]uffer' },
}
