-- VimQuest test suite: plays every story chapter with real keystrokes and checks known regressions
-- Run with tests/run.sh (it isolates saves in a temp folder and fakes a broken audio player)
local vq = require 'vimquest'
local ui = require 'vimquest.ui'
local sfx = require 'vimquest.sound'
local levels = require 'vimquest.levels'
local api = vim.api

local SLOW = tonumber(os.getenv 'VQ_SLOW' or '1')
local fails, total = 0, 0
local report = assert(io.open(os.getenv 'VQ_REPORT' or '/dev/stdout', 'w'))
local function out(s)
  report:write(s .. '\n')
  report:flush()
end
local function check(ok, what)
  total = total + 1
  if not ok then fails = fails + 1 end
  out((ok and '  ok    ' or '  FAIL  ') .. what)
end
local function wait(ms) coroutine.yield(math.floor(ms * SLOW)) end
local function keys(k, ms) api.nvim_input(k); wait(ms or 220) end
local function S() return vq._state() end
local function section(name) out('\n' .. name) end

local function close()
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_config(w).relative ~= '' then pcall(api.nvim_win_close, w, true) end
  end
  keys('<Esc>', 100)
  vim.cmd 'silent! tabfirst | silent! tabonly!'
  wait(300)
end

local function until_finished()
  for _ = 1, 30 do
    if S() and S().finished then return true end
    wait(150)
  end
  return S() and S().finished
end

local function stuck()
  local s = S()
  if not s then return 'no level running' end
  local o = s.L.objectives[s.obj] or {}
  return ('stuck on objective %d (%s), message: %s'):format(s.obj, o.text or '?', s.msg or '')
end

-- Breadth-first route through the maze to the nearest target, avoiding walls, traps and the guard
local function route(lines, from, targets)
  local function open(r, c)
    local ch = (lines[r] or ''):sub(c, c)
    return ch ~= '' and ch ~= '#' and ch ~= '^' and ch ~= 'M'
  end
  local q, prev, key, i = { from }, { [from[1] * 1000 + from[2]] = false }, {}, 1
  while q[i] do
    local r, c = q[i][1], q[i][2]
    i = i + 1
    if targets[r * 1000 + c] then
      local path, id = {}, r * 1000 + c
      while prev[id] do
        table.insert(path, 1, key[id])
        id = prev[id]
      end
      return path
    end
    for _, m in ipairs({ { 'j', 1, 0 }, { 'k', -1, 0 }, { 'l', 0, 1 }, { 'h', 0, -1 } }) do
      local id = (r + m[2]) * 1000 + c + m[3]
      if prev[id] == nil and open(r + m[2], c + m[3]) then
        prev[id], key[id] = r * 1000 + c, m[1]
        q[#q + 1] = { r + m[2], c + m[3] }
      end
    end
  end
end

local function cells(lines, ch)
  local t, any = {}, false
  for r, l in ipairs(lines) do
    for c = 1, #l do
      if l:sub(c, c) == ch then t[r * 1000 + c], any = true, true end
    end
  end
  return any and t or nil
end

-- One solution per chapter, typed exactly like a player would
local solutions = {
  function()
    for _ = 1, 4 do
      if S().finished then break end
      local lines = api.nvim_buf_get_lines(S().buf, 0, -1, false)
      local cur = api.nvim_win_get_cursor(S().win)
      local path = route(lines, { cur[1], cur[2] + 1 }, cells(lines, '*') or cells(lines, 'D'))
      if not path then break end
      for _, k in ipairs(path) do keys(k, 60) end
      wait(400)
    end
  end,
  function() keys '6w'; keys '$'; keys '0'; keys '6e'; keys '6b' end,
  function()
    for _ = 1, 4 do keys('gg', 80); keys('/X<CR>', 200); keys 'x' end
    for _ = 1, 3 do keys('gg', 80); keys('/SLIME<CR>', 200); keys 'dd' end
    wait(1500) -- the goblin strikes 0.6s after the task starts
    keys 'u'
  end,
  function()
    keys 'gg'; keys '0'; keys 'l'; keys 'a'; keys 'e'; keys '<Esc>'
    keys '/kights<CR>'; keys 'l'; keys 'i'; keys 'n'; keys '<Esc>'
    keys 'A'; keys ','; keys '<Esc>'
    keys 'o'; keys 'who never used a mouse.'; keys '<Esc>'
  end,
  function()
    keys 'w'; keys '*'; keys 'N'; keys 'ciw'; keys 'vim'; keys('<Esc>', 400)
    keys 'n'; keys '.'; keys 'n'; keys('.', 400)
    keys '4G'; keys '0'; keys 'w'; keys 'dw'
  end,
  function() keys('/KEY<CR>', 400); keys('G', 400); keys('gg', 400); keys '42G' end,
  function()
    keys(':%s/click/press/g<CR>', 500)
    keys('gg', 100); keys('/ARMOR<CR>', 300); keys 'V'; keys 'j'; keys 'j'; keys('d', 500)
    keys('/forbidden<CR>', 300); keys 'cw'; keys 'beloved'; keys('<Esc>', 400)
    keys(':w<CR>', 500)
  end,
  function()
    keys '/x<CR>'; keys 'ro'; keys 'n'; keys 'rh'
    keys '4G'; keys 'yy'; keys '2p'
    keys '2G'; keys 'w'; keys 'yw'; keys '8G'; keys '0'; keys '3l'; keys 'p'
    keys '4G'; keys 'O'; keys 'LONG LIVE THE KNIGHT'; keys '<Esc>'
    keys '/?<CR>'; keys 'R'; keys 'ESCAPE'; keys '<Esc>'
    keys '/never<CR>'; keys 'xxx'; keys 'U'
  end,
  function() keys '<C-g>'; keys '?GEAR<CR>'; keys 'n'; keys 'N'; keys '%'; keys '<C-o>'; keys '<Tab>' end,
  function() keys 'd$'; keys 'd2w'; keys 'ce'; keys 'er'; keys '<Esc>'; keys 'c$'; keys 'Waleed'; keys '<Esc>'; keys 'u'; keys '<C-r>' end,
  function()
    keys(':s/squeak/speak<CR>', 400); keys 'j'; keys(':s/squeak/speak/g<CR>', 400)
    keys(':5,7s/mouse/keyboard/g<CR>', 400); keys(':%s/cheese/bread/gc<CR>', 400)
    keys 'y'; keys 'y'; keys 'n'; keys 'y'
  end,
  function()
    keys(':!ls<CR>', 600); keys('<CR>', 300); keys(':w scroll.txt<CR>', 500)
    keys '4G'; keys '0'; keys 'v'; keys 'j'; keys ':'; keys('w secret.txt<CR>', 500)
    keys 'G'; keys(':r map.txt<CR>', 500); keys(':r !ls<CR>', 800)
  end,
  function()
    keys('/secret<CR>', 400); keys('<CR>', 200); keys(':set ic<CR>', 300); keys('/secret<CR>', 400)
    keys(':set hl', 200); keys('<C-d>', 300); keys('search<CR>', 400); keys('<CR>', 200)
    keys(':set incs', 200); keys('<Tab>', 300); keys('<CR>', 400); keys(':set noic<CR>', 400)
    keys(':help<CR>', 600); keys('<C-w><C-w>', 400); keys('<C-w><C-w>', 400); keys(':q<CR>', 500)
    keys(':echo $MYVIMRC<CR>', 500)
  end,
  function() keys(':q<CR>', 500); keys(':q!<CR>', 500); keys(':wq<CR>', 500); keys('ZZ', 500) end,
}

local function play(n)
  close()
  vq._play(n)
  wait(600)
end

local co = coroutine.create(function()
  ui.setup_hl()
  sfx.log = {}

  section 'Every story chapter clears with real keystrokes'
  local before = { vim.o.ignorecase, vim.o.smartcase, vim.o.hlsearch, vim.o.incsearch }
  for n, solve in ipairs(solutions) do
    play(n)
    local ok, err = pcall(solve)
    local done = until_finished()
    check(ok and done, ('chapter %d: %s%s'):format(n, levels.chapters[n].name, done and '' or ' - ' .. (ok and stuck() or err)))
    wait(400)
  end
  close()
  check(vim.deep_equal(before, { vim.o.ignorecase, vim.o.smartcase, vim.o.hlsearch, vim.o.incsearch }), 'search settings are restored after the Wizard\'s Study')

  section 'Chapter 5: * must come before ciw'
  local intro = levels.chapters[5].intro
  check(intro[2].press == '*' and intro[3].press == 'ciw', 'the story teaches * before ciw')
  check(levels.chapters[5].objectives[1].text:find('`%*`') ~= nil, 'the first objective mentions *')
  vim.fn.setreg('/', 'something else')
  play(5)
  keys 'w'; keys 'ciw'; keys 'vim'; keys('<Esc>', 500)
  check(S().obj == 2 and (S().msg or ''):find('No search yet') ~= nil, 'skipping * explains that n has nothing to find')
  keys('/mouse<CR>', 300); keys '.'; keys 'n'; keys('.', 500)
  check(S().obj >= 3, 'recovering with /mouse Enter then . n . works')

  section 'Chapter 8: the mirror reflection explains itself'
  play(8)
  local s8 = S()
  keys('l', 500)
  check((s8.msg or ''):find('just your reflection') ~= nil, 'the first move says the purple shape is a reflection')
  s8.msg = 'placeholder'
  local r = api.nvim_win_get_cursor(s8.win)[1]
  local len = #api.nvim_buf_get_lines(s8.buf, r - 1, r, false)[1]
  api.nvim_win_set_cursor(s8.win, { r, math.floor((len - 1) / 2) })
  wait(500)
  check((s8.msg or ''):find('touch the glass') ~= nil, 'meeting the reflection says it cannot be caught')
  s8.msg = 'placeholder'
  keys('h', 400); keys('l', 400)
  check(s8.msg == 'placeholder', 'each reflection message shows only once')

  section 'Chapter 12: a wrong selection is explained'
  play(12)
  keys(':!ls<CR>', 600); keys('<CR>', 300); keys(':w scroll.txt<CR>', 600)
  keys '4G'; keys '0'; keys 'v'; keys 'j'; keys 'j'; keys ':'; keys('w secret.txt<CR>', 900)
  check(S().obj == 3 and (S().msg or ''):find('has 3 lines') ~= nil, 'v j j (one line too many) is caught and explained')
  keys '4G'; keys '0'; keys 'v'; keys 'j'; keys ':'; keys('w! secret.txt<CR>', 900)
  check(S().obj == 4, 'redoing it with v j and :w! clears the objective')

  section 'Every story page opens'
  local pages, broken = 0, 0
  for _, ch in ipairs(levels.chapters) do
    local outro = type(ch.outro) == 'function' and ch.outro({ runes = {}, stars = {}, unlocked = 1 }) or ch.outro or {}
    for _, list in ipairs({ ch.intro or {}, outro }) do
      for _, p in ipairs(list) do
        local ok = pcall(ui.story, { p }, function() end)
        pages, broken = pages + 1, broken + (ok and 0 or 1)
        wait(120)
        close()
      end
    end
  end
  check(broken == 0, ('%d story pages open without errors'):format(pages))

  section 'Menu and credits'
  close()
  vim.cmd 'VimQuest'
  wait(700)
  keys('G', 300)
  check(api.nvim_get_current_line():find('Credits') ~= nil, 'G lands on Credits')
  keys('gg', 300)
  check(api.nvim_get_current_line():find('1%. The Cave') ~= nil, 'gg lands on chapter 1')
  close()
  check(pcall(vim.cmd, 'VimQuest credits'), 'credits roll')
  wait(1200)
  close()

  section 'Audio without a sound card'
  -- tests/run.sh puts fake afplay/paplay/aplay players on PATH that fail instantly and log each start
  sfx.log, sfx.enabled, sfx.music_on = nil, true, true
  local logfile = os.getenv 'VQ_PLAYER_LOG'
  if logfile then
    os.remove(logfile)
    sfx.music 'theme'
    wait(2500)
    sfx.stop_music()
    local starts = vim.uv.fs_stat(logfile) and #vim.fn.readfile(logfile) or 0
    check(starts == 1, ('a failing player is started once, not in a loop (started %d times)'):format(starts))
  else
    out '  skip  VQ_PLAYER_LOG not set (run through tests/run.sh)'
  end
  sfx.log = {}

  section 'No Lua errors'
  local bad = {}
  for line in api.nvim_exec2('messages', { output = true }).output:gmatch '[^\n]+' do
    if line:find 'E5108' or line:find 'stack traceback' or line:find 'vimquest/.-%.lua:%d+:' then bad[#bad + 1] = line end
  end
  check(#bad == 0, 'no errors in :messages' .. (#bad > 0 and ('\n        ' .. table.concat(bad, '\n        ')) or ''))

  out(('\n%d/%d checks passed'):format(total - fails, total))
end)

local function resume()
  local ok, ms = coroutine.resume(co)
  if not ok then
    out('CRASH: ' .. tostring(ms))
    return vim.cmd 'cquit 2'
  end
  if coroutine.status(co) == 'dead' then
    vim.cmd(fails == 0 and 'qa!' or 'cquit 1')
  else
    vim.defer_fn(resume, ms or 100)
  end
end
vim.defer_fn(resume, 500)
