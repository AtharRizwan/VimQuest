-- VimQuest: a story-mode game that teaches Neovim, played inside Neovim
local ui = require 'vimquest.ui'
local levels = require 'vimquest.levels'
local keyguide = require 'vimquest.keyguide'
local sfx = require 'vimquest.sound'
local api = vim.api
local M = {}

local save_path = vim.fs.joinpath(vim.fn.stdpath 'data', 'vimquest.json')
local key_ns = api.nvim_create_namespace 'vimquest_keys'
local hero_ns = api.nvim_create_namespace 'vimquest_hero'
local rune_ns = api.nvim_create_namespace 'vimquest_rune'
local eyes_ns = api.nvim_create_namespace 'vimquest_eyes'
local S

local function load()
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(save_path), '\n')) end)
  data = ok and type(data) == 'table' and data or {}
  data.unlocked = data.unlocked or 1
  data.stars = type(data.stars) == 'table' and data.stars or {}
  data.runes = type(data.runes) == 'table' and data.runes or {}
  return data
end

local function store(data) vim.fn.writefile({ vim.json.encode(data) }, save_path) end

local function rune_count(data)
  local n = 0
  for i = 1, 7 do
    if data.runes[tostring(i)] then n = n + 1 end
  end
  return n
end

local praise = { 'Well done, knight!', 'Splendid!', 'Your fingers fly!', 'Escarion nods approvingly.', 'Huzzah!', 'The Mouse King trembles.' }

local function refresh()
  if S and api.nvim_win_is_valid(S.win) then ui.panel(S) end
end

local NORMAL_HL = 'Normal:VQField,EndOfBuffer:VQField'
local DARK_HL = table.concat({
  'Normal:VQDark',
  'EndOfBuffer:VQDark',
  'LineNr:VQDark',
  'CursorLineNr:VQDark',
  'CursorLine:VQDark',
  'Search:VQDark',
  'CurSearch:VQDark',
  'VQWall:VQDarkWall',
  'VQGem:VQDark',
  'VQDoor:VQDark',
  'VQTrap:VQDark',
  'VQWater:VQDark',
  'VQTarget:VQDark',
  'VQBug:VQDark',
  'VQSlime:VQDark',
  'VQArmor:VQDark',
  'VQCurse:VQDark',
  'VQGold:VQDark',
  'VQHero:VQDark',
  'VQRuneText:VQDark',
}, ',')

-- Helpers handed to level hooks
local ctx = {}
local evaluate
function ctx.state() return S end
function ctx.buf() return S.buf end
function ctx.lines() return api.nvim_buf_get_lines(S.buf, 0, -1, false) end
function ctx.line(n) return api.nvim_buf_get_lines(S.buf, n - 1, n, false)[1] or '' end
function ctx.mode() return api.nvim_get_mode().mode end
function ctx.cursor()
  local p = api.nvim_win_get_cursor(S.win)
  return p[1], p[2]
end
function ctx.set_cursor(r, c)
  api.nvim_win_set_cursor(S.win, { r, c })
  S.prev = { r, c }
end
function ctx.say(msg, hl)
  S.msg, S.msg_hl = msg, hl
  refresh()
end
function ctx.edit(fn)
  local mod = vim.bo[S.buf].modifiable
  vim.bo[S.buf].modifiable = true
  fn()
  vim.bo[S.buf].modifiable = mod
end
function ctx.match(group, pattern) vim.fn.matchadd(group, pattern, 20, -1, { window = S.win }) end
function ctx.check() vim.schedule(function() evaluate() end) end

-- Was this key typed since the current objective started? (optionally in a given mode, e.g. 'c')
function ctx.typed(key, mode)
  key = key:upper()
  for i = S.obj_from, #S.typed do
    local t = S.typed[i]
    if t.key:upper() == key and (not mode or t.mode:sub(1, 1) == mode) then return true end
  end
  return false
end

-- Command lines entered since the current objective started, as { type = ':', line = 's/a/b' }
function ctx.cmds()
  return vim.list_slice(S.cmds, S.cmd_from)
end

function ctx.ran(pattern)
  for _, c in ipairs(ctx.cmds()) do
    if (c.type .. c.line):find(pattern) then return true end
  end
  return false
end
ctx.sound = sfx.play

-- Lights go out for a moment; with eyes, something stares back from the dark
function ctx.flicker(ms, eyes)
  if not S or S.calm then return end
  local win, buf = S.win, S.buf
  sfx.play('static', 200)
  vim.wo[win].winhighlight = DARK_HL
  if eyes then
    local top, bot = vim.fn.line('w0', win), vim.fn.line('w$', win)
    local row = math.random(top, math.max(top, bot)) - 1
    api.nvim_buf_set_extmark(buf, eyes_ns, row, 0, { id = 1, virt_text = { { string.rep(' ', math.random(1, 3)) .. '◉ ◉', 'VQEyes' } }, virt_text_pos = 'eol' })
  end
  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then vim.wo[win].winhighlight = NORMAL_HL end
    if api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_del_extmark, buf, eyes_ns, 1) end
  end, ms)
end

-- Draws the knight marker on the cursor cell in levels that want it
local function draw_hero()
  if not (S and S.L.hero) then return end
  local r, c = ctx.cursor()
  api.nvim_buf_set_extmark(S.buf, hero_ns, r - 1, c, { id = 1, virt_text = { { '@', 'VQHero' } }, virt_text_pos = 'overlay', priority = 400 })
end

-- Shows how to press each key the current objective needs
local function show_guide(stuck)
  local o = S.L.objectives[S.obj]
  if not o then return end
  local lines = keyguide.explain(o.text .. ' ' .. o.tip)
  if #lines == 0 then return ui.guide_close() end
  ui.guide(stuck and 'Stuck? These keys help' or 'Newbie guide: how to press', lines)
end

local function check_rune()
  local R = S.L.rune
  if not R or S.rune_found then return end
  local pos = api.nvim_buf_get_extmark_by_id(S.buf, rune_ns, 1, {})
  local r, c = ctx.cursor()
  if pos[1] ~= r - 1 or pos[2] ~= c then return end
  S.rune_found = true
  api.nvim_buf_del_extmark(S.buf, rune_ns, 1)
  local data = load()
  data.runes[tostring(S.n)] = true
  store(data)
  ctx.flicker(250, true)
  ui.rune(R.letter, rune_count(data), R.lore)
  S.msg, S.msg_hl = ('A RUNE! The letter %s burns into your mind...'):format(R.letter), 'VQRuneText'
end

local function cleanup()
  if not S then return end
  local s = S
  S = nil
  vim.on_key(nil, key_ns)
  if s.timer and not s.timer:is_closing() then s.timer:close() end
  if s.L.teardown then pcall(s.L.teardown, s) end
  vim.schedule(function() pcall(api.nvim_del_augroup_by_name, 'VimQuestLevel') end)
  ui.panel_close()
  ui.guide_close()
  sfx.stop_music()
  vim.o.mouse = s.mouse
end

local function close_level(s)
  if api.nvim_buf_is_valid(s.buf) then vim.bo[s.buf].modified = false end
  cleanup()
  if api.nvim_tabpage_is_valid(s.tab) and #api.nvim_list_tabpages() > 1 then
    api.nvim_set_current_tabpage(s.tab)
    vim.cmd 'tabclose'
  end
end

local run_chapter

local function finish()
  local s = S
  s.finished = true
  ui.guide_close()
  sfx.stop_music()
  local L = s.L
  local stars = s.keys <= L.par and 3 or (s.keys <= L.par * 1.5 and 2 or 1)
  local data = load()
  local best = data.stars[tostring(s.n)] or 0
  data.stars[tostring(s.n)] = math.max(best, stars)
  if not L.bonus and not L.secret then data.unlocked = math.max(data.unlocked, s.n + 1) end
  store(data)
  local msg = stars > best and best > 0 and 'New best!' or ({ 'Use fewer keys for 3 stars', 'So close to perfect!', 'Flawless technique!' })[stars]
  local secret = L.secret
  vim.defer_fn(function()
    ui.celebrate({ title = L.bonus and 'Bonus' or ('Chapter ' .. s.n), stars = stars, keys = s.keys, par = L.par, msg = msg, word = (L.victory or secret) and 'VICTORY' or 'CLEAR!' }, function()
      close_level(s)
      local outro = type(L.outro) == 'function' and L.outro(load()) or L.outro
      ui.story(outro, function()
        -- Story chapters lead into each other (the Void needs all 7 runes); bonus chapters chain separately
        local nxt = levels.chapters[s.n + 1]
        local go = nxt and (L.bonus and nxt.bonus or (not L.bonus and not nxt.bonus and (not nxt.secret or rune_count(load()) == 7)))
        if go then
          run_chapter(s.n + 1)
        elseif not L.bonus and (L.victory or L.secret) and s.n > 7 then
          ui.credits(M.menu)
        else
          M.menu()
        end
      end)
    end)
  end, 250)
end

evaluate = function()
  if not S or S.finished then return end
  if S.L.workspace then
    if not api.nvim_tabpage_is_valid(S.tab) then return cleanup() end
  elseif not api.nvim_win_is_valid(S.win) then
    return
  end
  local objs = S.L.objectives
  while S.obj <= #objs do
    local o = objs[S.obj]
    if not o.check(ctx) then
      if o.budget and S.obj_keys >= o.budget then
        S.obj_keys = 0
        S.msg, S.msg_hl = o.fail, 'VQBad'
        sfx.play 'splash'
        o.start(ctx)
      end
      break
    end
    S.obj = S.obj + 1
    S.obj_keys = 0
    S.obj_from, S.cmd_from = #S.typed + 1, #S.cmds + 1
    if S.obj <= #objs then sfx.play 'objective' end
    if S.sticky then
      S.sticky = nil
    else
      S.msg, S.msg_hl = '✨ ' .. praise[math.random(#praise)], 'VQGood'
    end
    if S.L.on_objective then S.L.on_objective(ctx) end
    local nxt = objs[S.obj]
    if nxt and nxt.start then nxt.start(ctx) end
    if nxt and S.newbie then show_guide() end
  end
  if S.obj > #objs then finish() end
  refresh()
end

local function play(n)
  local L = levels.chapters[n]
  local data = load()
  vim.cmd 'tabnew'
  local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  S = {
    n = n,
    L = L,
    buf = buf,
    win = win,
    tab = api.nvim_get_current_tabpage(),
    obj = 1,
    keys = 0,
    obj_keys = 0,
    t = 0,
    last_key = 0,
    typed = {},
    cmds = {},
    obj_from = 1,
    cmd_from = 1,
    mouse = vim.o.mouse,
    prev = { 1, 0 },
    newbie = not data.stars[tostring(n)],
    easy = data.easy,
    calm = data.calm,
  }
  ui.calm = data.calm
  sfx.enabled = not data.mute
  sfx.music_on = not data.nomusic
  sfx.music(L.music)

  vim.bo[buf].buftype = L.buftype or 'nofile'
  vim.bo[buf].bufhidden = L.workspace and 'hide' or 'wipe'
  vim.bo[buf].swapfile = false
  vim.b[buf].completion = false
  pcall(api.nvim_buf_set_name, buf, (type(L.file) == 'function' and L.file() or L.file) or ('vimquest-chapter-' .. n))
  vim.bo[buf].undolevels = -1
  api.nvim_buf_set_lines(buf, 0, -1, false, type(L.lines) == 'function' and L.lines() or L.lines)
  vim.bo[buf].undolevels = vim.go.undolevels
  vim.bo[buf].modifiable = L.modifiable
  vim.bo[buf].modified = L.start_modified or false

  local wo = vim.wo[win]
  wo.number, wo.relativenumber, wo.signcolumn, wo.wrap, wo.cursorline, wo.foldenable = true, true, 'no', false, not L.hero, false
  wo.winhighlight = NORMAL_HL
  wo.winbar = L.bonus and ('%#VQGold# ⚔ ' .. L.name .. ' %#VQDim# · :tabclose to leave') or ('%%#VQGold# ⚔ Chapter %d · %s %%#VQDim# · :q to leave'):format(n, L.name)
  vim.o.mouse = ''

  for _, k in ipairs({ '<Up>', '<Down>', '<Left>', '<Right>' }) do
    vim.keymap.set({ 'n', 'i', 'v' }, k, function()
      sfx.play('squeak', 150)
      ctx.say('🐭 The arrow keys are sealed by the Mouse King! Use h j k l.', 'VQBad')
    end, { buffer = buf })
  end
  if L.setup then L.setup(ctx) end
  if L.cwd then vim.cmd.tcd(vim.fn.fnameescape(L.cwd)) end
  if L.rune and not data.runes[tostring(n)] then
    api.nvim_buf_set_extmark(buf, rune_ns, L.rune.row - 1, L.rune.col, { id = 1, end_col = L.rune.col + 1, hl_group = 'VQRune', priority = 350 })
  end

  local g = api.nvim_create_augroup('VimQuestLevel', { clear = true })
  api.nvim_create_autocmd('CursorMoved', {
    group = g,
    buffer = buf,
    callback = function()
      if not S or S.finished then return end
      if L.on_move then L.on_move(ctx) end
      S.prev = { ctx.cursor() }
      draw_hero()
      check_rune()
      evaluate()
    end,
  })
  api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, { group = g, buffer = buf, callback = function() vim.schedule(evaluate) end })
  if L.on_write then
    api.nvim_create_autocmd('BufWriteCmd', {
      group = g,
      buffer = buf,
      callback = function()
        L.on_write(ctx)
        vim.bo[buf].modified = false
        evaluate()
      end,
    })
  end
  api.nvim_create_autocmd('BufWipeout', { group = g, buffer = buf, callback = cleanup })
  api.nvim_create_autocmd('TabClosed', {
    group = g,
    callback = function()
      if S and not api.nvim_tabpage_is_valid(S.tab) then cleanup() end
    end,
  })
  api.nvim_create_autocmd('CmdlineLeave', {
    group = g,
    callback = function()
      if not S or vim.v.event.abort or api.nvim_get_current_tabpage() ~= S.tab then return end
      S.cmds[#S.cmds + 1] = { type = vim.fn.getcmdtype(), line = vim.fn.getcmdline() }
      vim.schedule(evaluate)
    end,
  })
  -- A command line that grows by several letters at once was completed (Tab or a completion menu)
  api.nvim_create_autocmd({ 'CmdlineEnter', 'CmdlineChanged' }, {
    group = g,
    callback = function(ev)
      if not S or api.nvim_get_current_tabpage() ~= S.tab then return end
      local line = vim.fn.getcmdline()
      local prev = ev.event == 'CmdlineChanged' and S.cmdprev or nil
      if prev and #line >= #prev + 2 and line:sub(1, #prev) == prev then S.typed[#S.typed + 1] = { key = '<Tab>', mode = 'c' } end
      S.cmdprev = line
    end,
  })
  api.nvim_create_autocmd('ShellCmdPost', {
    group = g,
    callback = function()
      if not S then return end
      S.shell = true
      vim.schedule(evaluate)
    end,
  })
  api.nvim_create_autocmd('VimResized', { group = g, callback = refresh })

  vim.on_key(function(_, typed)
    if S and not S.finished and typed and typed ~= '' and api.nvim_get_current_tabpage() == S.tab then
      S.typed[#S.typed + 1] = { key = vim.fn.keytrans(typed), mode = api.nvim_get_mode().mode }
    end
    local here = S and (api.nvim_get_current_buf() == S.buf or (S.L.workspace and api.nvim_get_current_tabpage() == S.tab))
    if S and not S.finished and typed and typed ~= '' and here then
      S.keys = S.keys + 1
      S.obj_keys = S.obj_keys + 1
      S.last_key = S.t
      vim.schedule(function()
        local age = ui.guide_age()
        if age and age > 1500 then ui.guide_close() end
        refresh()
      end)
    end
  end, key_ns)

  -- Real-time clock for chasers, candles, counter-attacks and idle hints
  S.timer = vim.uv.new_timer()
  S.timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      if not S or S.finished then return end
      if S.L.workspace and not api.nvim_tabpage_is_valid(S.tab) then return cleanup() end
      if not S.L.workspace and not api.nvim_win_is_valid(S.win) then return end
      S.t = S.t + 100
      local before = S.alert and S.alert[1]
      if L.tick then L.tick(ctx) end
      if S.newbie and S.t - S.last_key > 15000 and not ui.guide_age() then
        S.last_key = S.t
        show_guide(true)
      end
      if (S.alert and S.alert[1]) ~= before then refresh() end
      if L.poll and S.t % 300 == 0 then evaluate() end
    end)
  )

  local first = L.objectives[1]
  if first.start then
    first.start(ctx)
  else
    ctx.set_cursor(1, 0)
  end
  draw_hero()
  if L.rune and not data.runes[tostring(n)] then
    ctx.say(L.rune.whisper, 'VQRuneText')
  else
    ctx.say('Escarion: "Good luck, Sir Cursor!"', 'VQSpeaker')
  end
  if S.newbie then show_guide() end
end

run_chapter = function(n)
  ui.setup_hl()
  ui.calm = load().calm
  sfx.enabled = not load().mute
  sfx.music_on = not load().nomusic
  sfx.music(levels.chapters[n].music)
  ui.story(levels.chapters[n].intro, function() play(n) end)
end

function M.menu()
  ui.setup_hl()
  sfx.enabled = not load().mute
  sfx.music_on = not load().nomusic
  ui.menu(levels.chapters, load(), function(i)
    if i == 'credits' then return ui.credits(M.menu) end
    run_chapter(i)
  end)
end

function M.command(arg)
  sfx.ensure()
  local data = load()
  if arg == 'reset' then
    store({ unlocked = 1, stars = {}, runes = {}, easy = data.easy, calm = data.calm, mute = data.mute, nomusic = data.nomusic })
    vim.notify('VimQuest progress reset', vim.log.levels.INFO)
    return
  end
  if arg == 'easy' or arg == 'calm' then
    data[arg] = not data[arg]
    store(data)
    local what = arg == 'easy' and 'Easy mode (no chasers or timers)' or 'Calm mode (no flicker or scares)'
    vim.notify(('VimQuest: %s %s'):format(what, data[arg] and 'ON' or 'OFF'), vim.log.levels.INFO)
    return
  end
  if arg == 'sound' then
    data.mute = not data.mute
    store(data)
    sfx.enabled = not data.mute
    if data.mute then sfx.stop_music() else sfx.play 'coin' end
    vim.notify(('VimQuest: sound %s'):format(data.mute and 'OFF' or 'ON'), vim.log.levels.INFO)
    return
  end
  if arg == 'music' then
    data.nomusic = not data.nomusic
    store(data)
    sfx.music_on = not data.nomusic
    if data.nomusic then
      sfx.stop_music()
    elseif S and not S.finished then
      sfx.music(S.L.music)
    end
    vim.notify(('VimQuest: music %s'):format(data.nomusic and 'OFF' or 'ON'), vim.log.levels.INFO)
    return
  end
  if S then close_level(S) end
  if arg == 'credits' then
    ui.setup_hl()
    sfx.enabled = not data.mute
    sfx.music_on = not data.nomusic
    return ui.credits()
  end
  M.menu()
end

-- Exposed for automated testing
M._state = function() return S end
M._play = play

return M
