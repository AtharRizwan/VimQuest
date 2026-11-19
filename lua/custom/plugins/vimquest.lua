-- VimQuest: a story-mode game that teaches Neovim, start it with :VimQuest
vim.api.nvim_create_user_command('VimQuest', function(o) require('vimquest').command(o.args) end, {
  nargs = '?',
  complete = function() return { 'reset', 'easy', 'calm', 'sound', 'music', 'credits' } end,
  desc = 'Play VimQuest',
})
