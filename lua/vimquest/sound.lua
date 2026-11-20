-- Plays VimQuest's retro sound effects in the background (afplay on macOS)
local M = { enabled = true, music_on = true }

local dir = vim.fs.joinpath(vim.fn.stdpath 'config', 'lua', 'vimquest', 'sfx')
local players = { { 'afplay' }, { 'paplay' }, { 'aplay', '-q' } }
local player
for _, p in ipairs(players) do
  if vim.fn.executable(p[1]) == 1 then
    player = p
    break
  end
end

local last, active = {}, 0

-- Sounds are synthesized locally; builds them in the background the first time if missing
function M.ensure()
  if vim.uv.fs_stat(vim.fs.joinpath(dir, 'theme.wav')) or M.building or vim.fn.executable 'python3' == 0 then return end
  M.building = true
  vim.notify('VimQuest: composing music and sound effects (one time, ~20s)...', vim.log.levels.INFO)
  vim.system({ 'python3', vim.fs.joinpath(dir, 'generate.py') }, {}, function(r)
    vim.schedule(function()
      M.building = false
      vim.notify(r.code == 0 and 'VimQuest: sounds ready!' or 'VimQuest: could not build sounds', r.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
    end)
  end)
end

-- gap = minimum milliseconds between two plays of the same sound
function M.play(name, gap)
  if not M.enabled then return end
  if M.log then
    M.log[#M.log + 1] = name
    return
  end
  local now = vim.uv.now()
  if last[name] and now - last[name] < (gap or 40) then return end
  local path = vim.fs.joinpath(dir, name .. '.wav')
  if not player or active >= 6 or not vim.uv.fs_stat(path) then return end
  last[name] = now
  active = active + 1
  local cmd = vim.list_extend(vim.deepcopy(player), { path })
  local ok = pcall(vim.system, cmd, {}, function() active = active - 1 end)
  if not ok then active = active - 1 end
end

local track, proc, gen = nil, nil, 0

-- Loops a music track until stop_music; asking for the track already playing does nothing
function M.music(name)
  if not M.enabled or not M.music_on or not name or track == name then return end
  M.stop_music()
  if M.log then
    M.log[#M.log + 1] = 'music:' .. name
    track = name
    return
  end
  local path = vim.fs.joinpath(dir, name .. '.wav')
  if not player or not vim.uv.fs_stat(path) then return end
  track = name
  gen = gen + 1
  local mine = gen
  local function loop()
    if gen ~= mine then return end
    local started = vim.uv.now()
    -- Only loop after a clean, full play; a player that fails at once (no sound card) would spin forever
    local ok, p = pcall(vim.system, vim.list_extend(vim.deepcopy(player), { path }), {}, function(r)
      if r.code == 0 and vim.uv.now() - started > 1000 then vim.schedule(loop) end
    end)
    proc = ok and p or nil
  end
  loop()
end

function M.stop_music()
  track = nil
  gen = gen + 1
  if proc then pcall(proc.kill, proc, 15) end
  proc = nil
end

vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() M.stop_music() end })

return M
