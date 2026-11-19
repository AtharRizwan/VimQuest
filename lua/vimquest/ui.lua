-- Floating windows for VimQuest: story scenes, menu, quest log, celebrations
local P = require 'vimquest.pixel'
local art = require 'vimquest.art'
local sfx = require 'vimquest.sound'
local api = vim.api
local M = {}

local ns_art = api.nvim_create_namespace 'vimquest_art'
local ns_text = api.nvim_create_namespace 'vimquest_text'

function M.setup_hl()
  local set = function(name, val) api.nvim_set_hl(0, name, val) end
  set('VQFloat', { bg = '#14121f', fg = '#e6e6f0' })
  set('VQBorder', { bg = '#14121f', fg = '#8f4bc4' })
  set('VQSpeaker', { fg = '#73eff7', bold = true })
  set('VQText', { fg = '#e6e6f0' })
  set('VQDim', { fg = '#6c6f93' })
  set('VQGold', { fg = '#ffcd75', bold = true })
  set('VQGood', { fg = '#a7f070', bold = true })
  set('VQBad', { fg = '#ff6b81', bold = true })
  set('VQKey', { fg = '#1a1c2c', bg = '#ffcd75', bold = true })
  set('VQSelect', { bg = '#2d2550', bold = true })
  set('VQHidden', { blend = 100, nocombine = true })
  set('VQField', { bg = '#100e17', fg = '#c9c9dd' })
  set('VQWall', { fg = '#6b4f3a', bg = '#6b4f3a' })
  set('VQGem', { fg = '#73eff7', bold = true })
  set('VQDoor', { fg = '#1a1c2c', bg = '#ffcd75', bold = true })
  set('VQTrap', { fg = '#ff004d', bold = true })
  set('VQWater', { fg = '#3b5dc9' })
  set('VQHero', { fg = '#1a1c2c', bg = '#ffcd75', bold = true })
  set('VQTarget', { fg = '#1a1c2c', bg = '#a7f070', bold = true })
  set('VQBug', { fg = '#ffffff', bg = '#c4002f', bold = true })
  set('VQSlime', { fg = '#38b764', bg = '#12301d' })
  set('VQArmor', { fg = '#94b0c2', bg = '#333c57', bold = true })
  set('VQRune', { fg = '#ffffff', bg = '#7b3fc4', bold = true })
  set('VQRuneText', { fg = '#c9a0ff', bold = true })
  set('VQTwin', { fg = '#ffffff', bg = '#7b3fc4', bold = true })
  set('VQGuard', { fg = '#ffffff', bg = '#c4002f', bold = true })
  set('VQDark', { fg = '#1c1a26', bg = '#040308' })
  set('VQDarkWall', { fg = '#0e0a08', bg = '#0e0a08' })
  set('VQEyes', { fg = '#ff2a2a', bg = '#040308', bold = true })
  set('VQCurse', { fg = '#ff6b81', underline = true })
end

-- Splits on spaces but keeps `key boxes` with spaces inside them in one piece
local function words(para)
  local out, open = {}, false
  for w in para:gmatch '%S+' do
    if open then
      out[#out] = out[#out] .. ' ' .. w
    else
      out[#out + 1] = w
    end
    local _, ticks = w:gsub('`', '')
    if ticks % 2 == 1 then open = not open end
  end
  return out
end

function M.wrap(text, width)
  local out = {}
  for para in (text .. '\n'):gmatch '(.-)\n' do
    local line = ''
    for _, word in ipairs(words(para)) do
      if line == '' then
        line = word
      elseif vim.fn.strdisplaywidth(line .. ' ' .. word) <= width then
        line = line .. ' ' .. word
      else
        out[#out + 1] = line
        line = word
      end
    end
    out[#out + 1] = line
  end
  return out
end

-- Turns `x` into a keycap segment, everything else uses the base highlight
function M.markup(text, base)
  local segs, i = {}, 1
  while true do
    local a, b = text:find('`[^`]+`', i)
    if not a then break end
    if a > i then segs[#segs + 1] = { text:sub(i, a - 1), base } end
    segs[#segs + 1] = { ' ' .. text:sub(a + 1, b - 1) .. ' ', 'VQKey' }
    i = b + 1
  end
  if i <= #text then segs[#segs + 1] = { text:sub(i), base } end
  return segs
end

-- Replaces lines from start onwards with rows of { text, hl } segments
function M.rich(buf, start, rows)
  local lines, marks = {}, {}
  for i, segs in ipairs(rows) do
    local parts, col = {}, 0
    for _, s in ipairs(segs) do
      parts[#parts + 1] = s[1]
      if s[2] then marks[#marks + 1] = { i - 1, col, col + #s[1], s[2] } end
      col = col + #s[1]
    end
    lines[i] = table.concat(parts)
  end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, start, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns_text, start, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, ns_text, start + m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
end

local function center(segs, width)
  local w = 0
  for _, s in ipairs(segs) do
    w = w + vim.fn.strdisplaywidth(s[1])
  end
  table.insert(segs, 1, { string.rep(' ', math.max(0, math.floor((width - w) / 2))) })
  return segs
end

local saved_cursor
local function hide_cursor()
  if not saved_cursor then saved_cursor = vim.o.guicursor end
  vim.o.guicursor = 'a:VQHidden'
end
local function show_cursor()
  if saved_cursor then vim.o.guicursor = saved_cursor end
  saved_cursor = nil
end

local function open(width, height, opts)
  opts = opts or {}
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  local win = api.nvim_open_win(buf, opts.enter ~= false, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = opts.title,
    title_pos = 'center',
    focusable = opts.enter ~= false,
    zindex = opts.zindex or 60,
  })
  vim.wo[win].winhighlight = 'Normal:VQFloat,FloatBorder:VQBorder,FloatTitle:VQGold,CursorLine:VQSelect,Search:VQFloat,CurSearch:VQFloat,IncSearch:VQFloat'
  vim.wo[win].wrap = false
  return buf, win
end

local function animate(win, ms, fn)
  local timer = vim.uv.new_timer()
  timer:start(
    0,
    ms,
    vim.schedule_wrap(function()
      if not api.nvim_win_is_valid(win) then
        if not timer:is_closing() then timer:close() end
        return
      end
      fn()
    end)
  )
  return timer
end

local function map(buf, keys, fn)
  for _, k in ipairs(keys) do
    vim.keymap.set('n', k, fn, { buffer = buf, nowait = true, silent = true })
  end
end

-- Every key a player might press during a story, mapped so nothing else happens
local story_keys = {}
for ch in ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$^:/*.,;!?%~#&-_=+[]{}()@\'"\\'):gmatch '.' do
  story_keys[#story_keys + 1] = ch
end
vim.list_extend(story_keys, { '<CR>', '<Space>', '<Esc>', '<BS>', '<Tab>', '<Up>', '<Down>', '<Left>', '<Right>', '<C-g>', '<C-o>', '<C-r>', '<C-w>', '<C-d>', '<C-l>', '<C-h>' })

-- Splits "d2w" or "<C-w><C-w>" into the individual keys to press
local function keylist(press)
  local out, i = {}, 1
  while i <= #press do
    local special = press:match('^<[^>]+>', i)
    out[#out + 1] = special or press:sub(i, i)
    i = i + (special and #special or 1)
  end
  return out
end

-- Plays story pages: { scene, cast, who, speaker, text, press?, fx? }
-- press = the key the player must type to continue; fx = 'flicker' | 'glitch' | 'scare'
function M.story(pages, on_done)
  local guide = require 'vimquest.keyguide'
  local W, H = 64, 20
  local buf, win = open(W, H / 2 + 8, { title = ' VimQuest ' })
  hide_cursor()
  local idx, shown, frame, tick, done = 1, 0, 0, 0, false
  local wrapped, total, want, progress, wrong, solved, esc_armed
  local stage = { dx = 0, dy = 0 }

  local function prep()
    local page = pages[idx]
    wrapped = M.wrap(page.text, W - 4)
    total = 0
    for _, l in ipairs(wrapped) do
      total = total + vim.fn.strchars(l)
    end
    want = page.press and keylist(page.press) or nil
    progress, wrong, solved, esc_armed = 0, nil, false, false
  end

  local function fx(name) return not M.calm and pages[idx].fx and pages[idx].fx:find(name) end

  local function draw_art()
    local c = P.new(W, H)
    if fx 'scare' and frame < 3 then
      art.scare(c, frame)
    else
      art.scenes[pages[idx].scene](c, frame)
      art.cast(c, pages[idx], frame, stage)
      if fx 'flicker' and (frame * 7919) % 10 < 2 then
        art.blackout(c, frame, pages[idx])
        sfx.play('static', 300)
      end
    end
    P.draw(buf, ns_art, c, 0)
  end

  local function glitch(text)
    if not fx 'glitch' or math.random() > 0.12 then return text end
    local chars = vim.fn.split(text, '\\zs')
    for _ = 1, math.random(1, 3) do
      local i = math.random(#chars > 0 and #chars or 1)
      if chars[i] and chars[i] ~= ' ' and chars[i] ~= '`' then chars[i] = ({ '▓', '▒', '░', '█', '#', '%' })[math.random(6)] end
    end
    return table.concat(chars)
  end

  local function draw_text()
    local page = pages[idx]
    local rows = { {}, { { '  ' .. (page.speaker or ''), (page.who == 'king' or page.who == 'stranger') and 'VQBad' or 'VQSpeaker' } } }
    local left = shown
    for i = 1, 4 do
      local l = wrapped[i] or ''
      local part = glitch(vim.fn.strcharpart(l, 0, math.max(0, left)))
      left = left - vim.fn.strchars(l)
      local segs = M.markup(part, 'VQText')
      table.insert(segs, 1, { '  ' })
      rows[#rows + 1] = segs
    end
    local blink = frame % 2 == 0 and '▶' or '▷'
    if shown < total then
      vim.list_extend(rows, { {}, {} })
    elseif esc_armed then
      rows[#rows + 1] = { { '  Press Esc again to skip the story', 'VQBad' } }
      rows[#rows + 1] = { { '  (any other key to keep reading)', 'VQDim' } }
    elseif solved then
      rows[#rows + 1] = { { '  ✓ Nice! ', 'VQGood' }, unpack(M.markup('`' .. guide.pretty(page.press) .. '`', 'VQGood')) }
      rows[#rows + 1] = {}
    elseif want then
      local line = M.markup(('  %s Press `%s` to continue'):format(blink, guide.pretty(page.press)), 'VQGold')
      if progress > 0 then line[#line + 1] = { ('   (%d/%d)'):format(progress, #want), 'VQGood' } end
      rows[#rows + 1] = line
      if wrong then
        local need = want[progress + 1]
        local hint = #wrong == 1 and wrong ~= need and (wrong:lower() == need or wrong:upper() == need) and ' - is Caps Lock on?' or ''
        rows[#rows + 1] = M.markup(('  ✗ That was `%s`%s Try `%s`'):format(guide.pretty(wrong), hint, guide.pretty(page.press)), 'VQBad')
      else
        rows[#rows + 1] = { { '  🔰 ' .. (guide.describe(page.press) or ''), 'VQDim' } }
      end
    else
      rows[#rows + 1] = M.markup(('  %s Press `Enter` to continue'):format(blink), 'VQGold')
      rows[#rows + 1] = { { ('  %d/%d   🔰 Enter is the big Return key · Esc Esc skips'):format(idx, #pages), 'VQDim' } }
    end
    M.rich(buf, H / 2, rows)
    pcall(api.nvim_win_set_cursor, win, { 1, 0 })
  end

  local function close()
    if done then return end
    done = true
    show_cursor()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    vim.schedule(on_done)
  end

  -- Each page can announce itself: a scare sting, or the Stranger's whisper
  local function page_sound()
    if fx 'scare' then
      sfx.play 'scare'
    elseif pages[idx].who == 'stranger' then
      sfx.play('whisper', 0)
    end
  end

  local function next_page()
    idx = idx + 1
    if idx > #pages then return close() end
    sfx.play 'page'
    prep()
    page_sound()
    shown = 0
    frame = 0
    draw_art()
    draw_text()
  end

  -- The hero reacts to movement keys so practice feels physical
  local function react(k)
    if k == 'l' or k == 'w' or k == 'e' or k == '$' then
      stage.dx = math.min(stage.dx + 4, 24)
    elseif k == 'h' or k == 'b' or k == '0' then
      stage.dx = math.max(stage.dx - 4, -4)
    else
      stage.dy = -2
      vim.defer_fn(function() stage.dy = 0 end, 250)
    end
    draw_art()
  end

  local function press(k)
    if done or solved then return end
    local press_esc = want and (want[progress + 1] == '<Esc>' or (shown >= total and want[1] == '<Esc>'))
    if k == '<Esc>' and not press_esc then
      if esc_armed then return close() end
      esc_armed = true
      sfx.play 'tick'
      return draw_text()
    end
    esc_armed = false
    if shown < total then
      shown = total
      return draw_text()
    end
    if not want then
      if k == '<CR>' or k == '<Space>' then next_page() end
      return
    end
    if k == want[progress + 1] then
      progress = progress + 1
      wrong = nil
      react(k)
      if progress == #want then
        sfx.play 'ok'
        solved = true
        draw_text()
        vim.defer_fn(next_page, 650)
        return
      end
      sfx.play 'blip'
    else
      sfx.play 'error'
      progress = 0
      wrong = k
    end
    draw_text()
  end

  prep()
  page_sound()
  draw_art()
  draw_text()
  animate(win, 30, function()
    tick = tick + 1
    if shown < total then
      shown = shown + 2
      sfx.play('blip', 55)
      draw_text()
    end
    if tick % 8 == 0 then
      frame = frame + 1
      draw_art()
      draw_text()
    end
  end)
  for _, k in ipairs(story_keys) do
    vim.keymap.set('n', k, function() press(k) end, { buffer = buf, nowait = true, silent = true })
  end
  api.nvim_create_autocmd('WinLeave', { buffer = buf, once = true, callback = function() vim.schedule(close) end })
end

-- Chapter select screen; j/k to move, Enter to play. Locked rows and headers are skipped.
function M.menu(chapters, save, on_pick)
  local regular, runes = 0, 0
  for _, ch in ipairs(chapters) do
    if not ch.secret and not ch.bonus then regular = regular + 1 end
  end
  for i = 1, 7 do
    if save.runes[tostring(i)] then runes = runes + 1 end
  end
  local function available(i, ch)
    if ch.bonus then return true end
    if ch.secret then return save.unlocked > regular and runes == 7 end
    return i <= save.unlocked
  end

  local rune_row = { { '  Runes  ', 'VQDim' } }
  for i = 1, 7 do
    local r = save.runes[tostring(i)]
    rune_row[#rune_row + 1] = { r and (chapters[i].rune.letter .. ' ') or '· ', r and 'VQRuneText' or 'VQDim' }
  end
  if runes == 7 then rune_row[#rune_row + 1] = { '  the Void is open...', 'VQRuneText' } end
  local W = 64
  local rows, target, start = { rune_row }, {}, nil
  local bonus_header = false
  for i, ch in ipairs(chapters) do
    if ch.bonus and not bonus_header then
      bonus_header = true
      rows[#rows + 1] = { { '  ── Bonus: Real-World Neovim · always open ──', 'VQGood' } }
    end
    local open = available(i, ch)
    local name = ch.bonus and ('  ' .. ch.name) or ('  %d. %s'):format(i, ch.name)
    if open then
      local stars = save.stars[tostring(i)] or 0
      rows[#rows + 1] = {
        { name, ch.secret and 'VQRuneText' or 'VQText' },
        { string.rep(' ', math.max(1, W - 6 - vim.fn.strdisplaywidth(name))) },
        { string.rep('★', stars), 'VQGold' },
        { string.rep('☆', 3 - stars), 'VQDim' },
      }
      target[#rows] = i
      if not ch.bonus and not ch.secret then start = #rows end
    elseif ch.secret then
      rows[#rows + 1] = { { ('  %d. ??? Something waits behind the runes...'):format(i), 'VQDim' } }
    else
      rows[#rows + 1] = { { ('  %d. ??? locked%s'):format(i, i == 8 and '   - Act II' or ''), 'VQDim' } }
    end
  end
  rows[#rows + 1] = { { '  ♥ Credits', 'VQGold' } }
  target[#rows] = 'credits'
  rows[#rows + 1] = M.markup('  `j` `k` move   `Enter` play   `q` quit', 'VQDim')

  local art_rows = math.max(4, math.min(11, vim.o.lines - 5 - #rows))
  local H = art_rows * 2
  local buf, win = open(W, math.min(art_rows + #rows, vim.o.lines - 3), { title = ' VimQuest · The Vim Knight ' })
  vim.wo[win].cursorline = true
  vim.wo[win].scrolloff = 2
  local frame = 0

  local function draw()
    local c = P.new(W, H)
    art.title(c, frame)
    P.draw(buf, ns_art, c, 0)
  end
  draw()
  M.rich(buf, art_rows, rows)
  local row_of = function(r) return art_rows + r end
  local last = row_of(start or 2)
  api.nvim_win_set_cursor(win, { last, 0 })
  animate(win, 250, function()
    frame = frame + 1
    draw()
  end)

  api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local r = api.nvim_win_get_cursor(win)[1]
      if target[r - art_rows] then
        if r ~= last then sfx.play 'tick' end
        last = r
        return
      end
      local probe
      for _, dir in ipairs(r >= last and { 1, -1 } or { -1, 1 }) do
        probe = math.min(math.max(r, art_rows + 1), art_rows + #rows)
        while probe > art_rows and probe <= art_rows + #rows and not target[probe - art_rows] do
          probe = probe + dir
        end
        if target[probe - art_rows] then break end
      end
      if not target[probe - art_rows] then probe = last end
      if probe ~= last then sfx.play 'tick' end
      last = probe
      api.nvim_win_set_cursor(win, { probe, 0 })
    end,
  })
  sfx.music 'theme'
  local keep_music = false
  api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      if not keep_music then sfx.stop_music() end
    end,
  })
  local function pick(i)
    if not i then return end
    sfx.play 'select'
    keep_music = i == 'credits'
    api.nvim_win_close(win, true)
    vim.schedule(function() on_pick(i) end)
  end
  map(buf, { '<CR>', '<Space>' }, function() pick(target[api.nvim_win_get_cursor(win)[1] - art_rows]) end)
  map(buf, { 'q', '<Esc>' }, function() api.nvim_win_close(win, true) end)
end

-- Big "CLEAR!" screen with fireworks and the star rating
function M.celebrate(info, on_done)
  local W, H = 48, 14
  local buf, win = open(W, H / 2 + 6, { title = ' ' .. info.title .. ' ', zindex = 80 })
  sfx.play(info.word == 'VICTORY' and 'victory' or 'fanfare')
  hide_cursor()
  local frame, done = 0, false
  local rows = {
    {},
    center({ { string.rep('★ ', info.stars), 'VQGold' }, { string.rep('☆ ', 3 - info.stars), 'VQDim' } }, W),
    center({ { 'Keystrokes ', 'VQDim' }, { tostring(info.keys), 'VQGold' }, { '   Par ', 'VQDim' }, { tostring(info.par), 'VQText' } }, W),
    center({ { info.msg or '', 'VQGood' } }, W),
    {},
    center({ { '▸ Enter to continue', 'VQGold' } }, W),
  }
  local function draw()
    local c = P.new(W, H)
    art.clear(c, frame, info.word or 'CLEAR!')
    P.draw(buf, ns_art, c, 0)
  end
  draw()
  M.rich(buf, H / 2, rows)
  animate(win, 120, function()
    frame = frame + 1
    draw()
  end)
  local function close()
    if done then return end
    done = true
    show_cursor()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    vim.schedule(on_done)
  end
  map(buf, { '<CR>', '<Space>', '<Esc>', 'q' }, close)
end

-- Every job in the studio went to the same person
local NAME = 'Muhammad Waleed'
local EMAIL = 'muhammadwaleed6824@gmail.com'
local roles = {
  { 'Directed by' },
  { 'Written by', 'scroll' },
  { 'Story, Lore & Suspicious Plot Twists', 'scroll' },
  { 'Sir Cursor, the Vim Knight', 'hero' },
  { 'Escarion the Wise', 'wizard' },
  { 'Lord Clickmore (Villain, Mouse Enthusiast)', 'king' },
  { 'The ??? Lurking in the Dark', 'stranger' },
  { 'Sir Cursor\'s Evil Mirror Twin', 'hero' },
  { 'The Trackpad Golem (in a rubber suit)' },
  { 'Emotional Support Frog', 'frog' },
  { 'Pixel Art, One ▀ at a Time', 'gem' },
  { 'Every Beep, Boop, Bonk & Bong' },
  { 'The Midnight Clock Bell (live recording)' },
  { 'Scary Glowing Eyes', 'stranger' },
  { 'Keyboard Choreography', 'key' },
  { 'Lead Bug Creator', 'bug' },
  { 'Lead Bug Fixer', 'bug' },
  { 'Quality Assurance (pressed :q 400 times)' },
  { 'Stunt Double for the Esc Key', 'key' },
  { 'Catering (one cup of chai)' },
  { 'Person Who Still Can\'t Exit Vim', 'hero' },
  { 'Marketing, Legal & Customer Support' },
  { 'Special Thanks' },
  { 'And Starring, for the First Time...' },
}

-- Movie-style credits that scroll up under a fireworks show
function M.credits(on_done)
  local W, H, TR = 64, 20, 8
  local buf, win = open(W, H / 2 + TR, { title = ' Credits ', zindex = 80 })
  hide_cursor()
  sfx.play 'victory'
  local guests = {}
  local lines = { center({ { 'V I M Q U E S T', 'VQGold' } }, W), center({ { 'a ' .. NAME .. ' production', 'VQDim' } }, W), {}, {} }
  for _, r in ipairs(roles) do
    lines[#lines + 1] = center({ { r[1], 'VQDim' } }, W)
    guests[#lines] = r[2] or 'none'
    lines[#lines + 1] = center({ { NAME, 'VQGold' } }, W)
    lines[#lines + 1] = {}
  end
  vim.list_extend(lines, {
    {},
    center({ { 'No mice were harmed in the making of this game.', 'VQDim' } }, W),
    center({ { 'Several were mildly inconvenienced.', 'VQDim' } }, W),
    {},
    {},
  })
  local last = #lines + 1
  vim.list_extend(lines, {
    center({ { 'Made with ♥ and zero mouse clicks by', 'VQText' } }, W),
    center({ { NAME, 'VQGold' } }, W),
    {},
    center({ { 'Questions, ideas, bugs, or just say hi:', 'VQDim' } }, W),
    center({ { EMAIL, 'VQGood' } }, W),
    {},
    center({ { 'Thanks for playing, Vim Knight!', 'VQSpeaker' } }, W),
    center({ { '▸ Enter to close', 'VQGold' } }, W),
  })
  local offset, frame, tick, fast, done, guest = -TR, 0, 0, false, false, 'none'
  local stop = last - 1

  local function draw()
    local c = P.new(W, H)
    art.credits(c, frame, guest)
    P.draw(buf, ns_art, c, 0)
    local rows = {}
    for i = 1, TR do
      rows[i] = lines[offset + i] or {}
    end
    M.rich(buf, H / 2, rows)
  end

  local function close()
    if done then return end
    done = true
    show_cursor()
    sfx.stop_music()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    if on_done then vim.schedule(on_done) end
  end
  vim.defer_fn(function()
    if not done then sfx.music 'theme' end
  end, 2500)

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(string.rep('\n', H / 2 + TR - 1), '\n'))
  vim.bo[buf].modifiable = false
  draw()
  animate(win, 100, function()
    tick = tick + 1
    if tick % 3 == 0 then frame = frame + 1 end
    if offset < stop and (fast or tick % 6 == 0) then
      offset = offset + 1
      for i = offset + TR - 1, 1, -1 do
        if guests[i] then
          guest = guests[i]
          break
        end
      end
      if offset == stop then sfx.play 'fanfare' end
    end
    draw()
  end)
  map(buf, { '<CR>', '<Space>', 'j' }, function()
    if offset >= stop then return close() end
    fast = true
  end)
  map(buf, { '<Esc>', 'q' }, close)
end

-- Boss flashes and shakes when hit, then the popup closes by itself
function M.hurt(hp, max, title)
  local W, H = 26, 18
  local buf, win = open(W, H / 2 + 2, { enter = false, title = ' ' .. (title or 'Lord Clickmore') .. ' ', zindex = 70 })
  sfx.play 'hit'
  local frame = 0
  local function draw()
    local c = P.new(W, H)
    art.hurt(c, frame)
    P.draw(buf, ns_art, c, 0)
  end
  draw()
  M.rich(buf, H / 2, {
    center({ { 'HP ', 'VQDim' }, { string.rep('♥', hp), 'VQBad' }, { string.rep('♡', max - hp), 'VQDim' } }, W),
    center({ { hp > 0 and 'ARGH! My clicks!' or 'NOOOOO!', 'VQGold' } }, W),
  })
  animate(win, 90, function()
    frame = frame + 1
    if frame < 8 then draw() end
  end)
  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end, 1600)
end

-- A rune was found: glowing letter plus a whisper from the Stranger
function M.rune(letter, count, lore)
  local W, H = 32, 16
  local buf, win = open(W, H / 2 + 5, { enter = false, title = (' Rune %d/7 '):format(count), zindex = 75 })
  sfx.play 'rune'
  vim.wo[win].winhighlight = 'Normal:VQFloat,FloatBorder:VQRuneText,FloatTitle:VQRuneText'
  local frame = 0
  local function draw()
    local c = P.new(W, H)
    art.rune(c, frame, letter)
    P.draw(buf, ns_art, c, 0)
  end
  draw()
  local rows = { center({ { 'You found the rune  ' .. letter, 'VQRuneText' } }, W) }
  for _, l in ipairs(M.wrap(lore, W - 2)) do
    rows[#rows + 1] = center({ { l, 'VQDim' } }, W)
  end
  M.rich(buf, H / 2, rows)
  animate(win, 150, function()
    frame = frame + 1
    draw()
  end)
  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end, 4500)
end

local guide = {}

-- Beginner guide in the bottom-left corner; closes once the player starts pressing keys
function M.guide(title, lines)
  M.guide_close()
  local W = math.max(30, math.min(44, vim.o.columns - 38))
  local rows = {}
  for _, line in ipairs(lines) do
    for _, l in ipairs(M.wrap(line, W - 3)) do
      local segs = M.markup(l, 'VQText')
      table.insert(segs, 1, { ' ' })
      rows[#rows + 1] = segs
    end
  end
  guide.buf = api.nvim_create_buf(false, true)
  vim.bo[guide.buf].bufhidden = 'wipe'
  guide.win = api.nvim_open_win(guide.buf, false, {
    relative = 'editor',
    anchor = 'SW',
    row = vim.o.lines - 2,
    col = 0,
    width = W,
    height = math.max(1, math.min(#rows, 6)),
    style = 'minimal',
    border = 'rounded',
    title = ' 🔰 ' .. title .. ' ',
    title_pos = 'left',
    focusable = false,
    zindex = 35,
  })
  vim.wo[guide.win].winhighlight = 'Normal:VQFloat,FloatBorder:VQGood,FloatTitle:VQGood,Search:VQFloat,CurSearch:VQFloat,IncSearch:VQFloat'
  M.rich(guide.buf, 0, rows)
  guide.opened = vim.uv.now()
end

function M.guide_age() return guide.win and api.nvim_win_is_valid(guide.win) and vim.uv.now() - guide.opened or nil end

function M.guide_close()
  if guide.win and api.nvim_win_is_valid(guide.win) then api.nvim_win_close(guide.win, true) end
  guide.win = nil
end

local panel = {}

-- Quest log in the top-right corner of a level
function M.panel(S)
  local W = 34
  local L = S.L
  local o = L.objectives[S.obj]
  local rows = {}
  local function add(segs) rows[#rows + 1] = segs end
  local function sep() add({ { ' ' .. string.rep('─', W - 2), 'VQDim' } }) end

  local label = L.bonus and 'Bonus' or ('Chapter ' .. S.n)
  add({ { ' ⚔ QUEST LOG', 'VQGold' }, { string.rep(' ', W - 14 - #label) }, { label, 'VQDim' } })
  add({ { ' ' .. L.name, 'VQSpeaker' } })
  sep()
  -- Long chapters show a summary of finished tasks plus the next few; workspace chapters only the current one
  local from, to = 1, #L.objectives
  if L.workspace then
    from, to = S.obj, S.obj
    if from > 1 then add({ { (' ✓ %d of %d done'):format(from - 1, #L.objectives), 'VQGood' } }) end
  elseif #L.objectives > 5 then
    from, to = math.max(1, S.obj), math.min(#L.objectives, S.obj + 2)
    if from > 1 then add({ { (' ✓ %d done'):format(from - 1), 'VQGood' } }) end
  end
  for i, ob in ipairs(L.objectives) do
    if i < from or i > to then goto continue end
    local mark, mhl, thl = ' · ', 'VQDim', 'VQDim'
    if i < S.obj then
      mark, mhl, thl = ' ✓ ', 'VQGood', 'VQGood'
    elseif i == S.obj then
      mark, mhl, thl = ' ▸ ', 'VQGold', 'VQText'
    end
    for j, l in ipairs(M.wrap(ob.text, W - 4)) do
      local segs = M.markup(l, thl)
      table.insert(segs, 1, { j == 1 and mark or '   ', mhl })
      add(segs)
    end
    ::continue::
  end
  if to < #L.objectives and not L.workspace then add({ { ('   +%d more'):format(#L.objectives - to), 'VQDim' } }) end
  if o and o.tip then
    sep()
    for _, l in ipairs(M.wrap(o.tip, W - 3)) do
      local segs = M.markup(l, 'VQText')
      table.insert(segs, 1, { ' ' })
      add(segs)
    end
  end
  sep()
  -- The key reference is dropped first when the screen is too short
  local ref_at = #rows
  for _, k in ipairs(L.workspace and {} or L.keys) do
    local segs = M.markup(k, 'VQDim')
    table.insert(segs, 1, { ' ' })
    add(segs)
  end
  if not L.workspace then sep() end
  local ref_len = #rows - ref_at
  local stat = { { ' Keys ', 'VQDim' }, { tostring(S.keys), 'VQGold' }, { '  Par ', 'VQDim' }, { tostring(L.par), 'VQText' } }
  if o and o.budget then
    local left = math.max(0, o.budget - S.obj_keys)
    vim.list_extend(stat, { { '  Moves ', 'VQDim' }, { tostring(left), left <= 1 and 'VQBad' or 'VQGood' } })
  end
  add(stat)
  if S.alert then add({ { ' ' .. S.alert[1], S.alert[2] } }) end
  if S.msg then
    for _, l in ipairs(M.wrap(S.msg, W - 3)) do
      add({ { ' ' .. l, S.msg_hl or 'VQText' } })
    end
  end

  local max = vim.o.lines - 6
  if #rows > max then
    for _ = 1, ref_len do
      table.remove(rows, ref_at + 1)
    end
  end
  local height = math.min(#rows, max)
  local cfg = { relative = 'editor', anchor = 'NE', row = 1, col = vim.o.columns, width = W, height = height }
  if L.workspace then cfg.anchor, cfg.row = 'SE', vim.o.lines - 2 end
  if not (panel.win and api.nvim_win_is_valid(panel.win)) then
    panel.buf = api.nvim_create_buf(false, true)
    vim.bo[panel.buf].bufhidden = 'wipe'
    cfg.style, cfg.border, cfg.focusable, cfg.zindex = 'minimal', 'rounded', false, 30
    panel.win = api.nvim_open_win(panel.buf, false, cfg)
    vim.wo[panel.win].winhighlight = 'Normal:VQFloat,FloatBorder:VQBorder,Search:VQFloat,CurSearch:VQFloat,IncSearch:VQFloat'
  else
    api.nvim_win_set_config(panel.win, cfg)
  end
  M.rich(panel.buf, 0, rows)
end

function M.panel_close()
  if panel.win and api.nvim_win_is_valid(panel.win) then api.nvim_win_close(panel.win, true) end
  panel.win = nil
end

return M
