-- Chapter definitions: story pages, buffer content, objectives, thrills and runes
local api = vim.api
local M = {}

local ns = api.nvim_create_namespace 'vimquest_target'
local guard_ns = api.nvim_create_namespace 'vimquest_guard'

local function page(who, scene, text, extra)
  local names = { wizard = 'Escarion the Wise', hero = 'Sir Cursor', king = 'Lord Clickmore', stranger = '???', narrator = 'Narrator' }
  local casts = { wizard = { 'hero', 'wizard' }, hero = { 'hero', 'wizard' }, king = { 'hero', 'king' }, stranger = { 'hero', 'stranger' }, narrator = { 'hero' } }
  return vim.tbl_extend('force', { scene = scene, cast = casts[who], who = who, speaker = names[who], text = text }, extra or {})
end
local function wizard(scene, text, press) return page('wizard', scene, text, { press = press }) end
local function hero(scene, text) return page('hero', scene, text) end
local function king(scene, text) return page('king', scene, text) end
local function stranger(scene, text, fx) return page('stranger', scene, text, { fx = fx or 'flicker glitch' }) end

local function eq(a, b) return vim.deep_equal(a, b) end

local function word_range(line, word)
  local s = line:find(word, 1, true)
  return s - 1, s - 2 + #word
end

local function mark(ctx, row, a, b)
  api.nvim_buf_clear_namespace(ctx.buf(), ns, 0, -1)
  if row then api.nvim_buf_set_extmark(ctx.buf(), ns, row - 1, a, { end_col = b + 1, hl_group = 'VQTarget', priority = 300 }) end
end

local function count(lines, pat)
  local n = 0
  for _, l in ipairs(lines) do
    for _ in l:gmatch(pat) do
      n = n + 1
    end
  end
  return n
end

-- Chapter 1: hjkl maze with a hunting Mouse Guard -------------------------------

local maze = {
  '####################################',
  '#S   #         #        #          #',
  '# ## # ####### # ###### # ######## #',
  '# #  #    *  # #      # #        # #',
  '# # ######## # ###### # ######## # #',
  '# #          #      # #        #   #',
  '# ############ #### # ########## ###',
  '#              #  ^ #       *      #',
  '###### ######### ## ######## ##### #',
  '#    #       #   ##     #      #   #',
  '# *  # ##### # ^  ##### # #### # # #',
  '#      #       #          #      #D#',
  '####################################',
}
local START, DOOR, GUARD = { 2, 1 }, { 12, 34 }, { 6, 30 }

local function cell(ctx, r, c) return ctx.line(r):sub(c + 1, c + 1) end

local function maze_move(ctx)
  local S = ctx.state()
  local pr, pc = S.prev[1], S.prev[2]
  local r, c = ctx.cursor()
  if r == pr and c == pc then return end
  local path = {}
  if r == pr then
    local step = c > pc and 1 or -1
    for x = pc + step, c, step do
      path[#path + 1] = { r, x }
    end
  elseif c == pc then
    local step = r > pr and 1 or -1
    for y = pr + step, r, step do
      path[#path + 1] = { y, c }
    end
  else
    path = { { r, c } }
  end
  local lr, lc = pr, pc
  for _, p in ipairs(path) do
    local ch = cell(ctx, p[1], p[2])
    if ch == '#' or ch == '' then
      ctx.sound('bonk', 120)
      ctx.say(({ 'Bonk! Solid rock.', 'Ouch, a wall!', 'Clang! Your helmet hits stone.' })[math.random(3)], 'VQBad')
      break
    end
    lr, lc = p[1], p[2]
    ctx.sound('step', 60)
    if ch == '^' then
      ctx.sound 'snap'
      ctx.say('SNAP! A mouse trap! Back to the cave entrance...', 'VQBad')
      ctx.flicker(150)
      lr, lc = START[1], START[2]
      break
    end
    if ch == '*' then
      ctx.edit(function() api.nvim_buf_set_text(ctx.buf(), p[1] - 1, p[2], p[1] - 1, p[2] + 1, { ' ' }) end)
      local left = count(ctx.lines(), '%*')
      ctx.sound 'coin'
      ctx.say(left > 0 and ('Gem collected! %d to go.'):format(left) or 'All 3 gems! Now find the door D.', 'VQGood')
    end
    if ch == 'D' and count(ctx.lines(), '%*') > 0 then ctx.say('The door is sealed. Collect every gem first!', 'VQBad') end
  end
  if lr ~= r or lc ~= c then ctx.set_cursor(lr, lc) end
end

-- Breadth-first search through the maze: first step from a toward b and the distance
local function chase(ctx, a, b)
  local lines = ctx.lines()
  local key = function(r, c) return r * 100 + c end
  local prev, queue, head = { [key(a[1], a[2])] = false }, { a }, 1
  while queue[head] do
    local p = queue[head]
    head = head + 1
    if p[1] == b[1] and p[2] == b[2] then
      local path = { p }
      while prev[key(path[#path][1], path[#path][2])] do
        path[#path + 1] = prev[key(path[#path][1], path[#path][2])]
      end
      return path[#path - 1], #path - 1
    end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local r, c = p[1] + d[1], p[2] + d[2]
      local ch = (lines[r] or ''):sub(c + 1, c + 1)
      if ch ~= '' and ch ~= '#' and prev[key(r, c)] == nil then
        prev[key(r, c)] = p
        queue[#queue + 1] = { r, c }
      end
    end
  end
end

local function guard_tick(ctx)
  local S = ctx.state()
  if S.easy then return end
  local g = S.guard
  if not g then
    g = { pos = { GUARD[1], GUARD[2] }, next = 0, dist = 99 }
    S.guard = g
  end
  local hr, hc = ctx.cursor()
  local wake = S.newbie and 10000 or 3000
  if S.keys > 0 and S.t > wake and S.t >= g.next then
    g.next = S.t + (S.newbie and 1300 or 900)
    local step, dist = chase(ctx, g.pos, { hr, hc })
    if step then g.pos = step end
    g.dist = dist and dist - 1 or 99
  end
  if g.pos[1] == hr and g.pos[2] == hc then
    ctx.sound 'caught'
    ctx.flicker(500, true)
    ctx.set_cursor(START[1], START[2])
    g.pos, g.next, g.dist = { GUARD[1], GUARD[2] }, S.t + 4000, 99
    ctx.say('AAAH! The Mouse Guard grabbed you and dragged you back to the entrance! (Your gems are safe.)', 'VQBad')
  end
  api.nvim_buf_set_extmark(S.buf, guard_ns, g.pos[1] - 1, g.pos[2], { id = 1, virt_text = { { 'M', 'VQGuard' } }, virt_text_pos = 'overlay', priority = 450 })
  if S.keys == 0 or S.t <= wake then
    S.alert = { '👁 Something sleeps... (M)', 'VQDim' }
  elseif g.dist <= 6 then
    ctx.sound('heartbeat', 450 + g.dist * 150)
    S.alert = { ('♥♥ Guard %d steps away! RUN!'):format(g.dist), 'VQBad' }
    if math.random() < 0.035 then ctx.flicker(140, true) end
  else
    S.alert = { ('👁 The Guard hunts you: %d steps'):format(g.dist), 'VQDim' }
  end
end

-- Chapter 3/4/5 targets ---------------------------------------------------------

local scroll = {
  'Royal Scroll of Textoria',
  'The kingdom was calm and bright.',
  'Every scroll was written with love.',
  'Then the Mouse King sent his bugs.',
}

local function no_slime(lines)
  return vim.tbl_filter(function(l) return not l:find('SLIME', 1, true) end, lines)
end

local bridge = { 'The bridge over the canyon', 'was built by brave knights,', 'who never used a mouse.' }

local spell = {
  'The cursed spell of the king:',
  'the vim is wise, the vim is strong,',
  'bow to the vim or be gone.',
  'the evil king laughs.',
}

-- Chapter 6 library -----------------------------------------------------------------

local function library()
  local r = require('vimquest.pixel').rng(42)
  local adj = { 'dusty', 'ancient', 'tiny', 'enormous', 'boring', 'glowing', 'soggy', 'forbidden', 'haunted', 'sleepy' }
  local things = {
    'atlas of semicolons',
    'diary of a monkey',
    'keyboard yoga guide',
    'cheese soup recipes',
    'map of turkey hills',
    'poem about a donkey',
    'manual for dragons',
    'hockey war history',
    'tabs vs spaces saga',
    'book of regexes',
  }
  local lines = { '=== THE LIBRARY OF ECHOES ===' }
  for i = 2, 150 do
    lines[i] = ('%03d %s %s'):format(i, adj[r(#adj) + 1], things[r(#things) + 1])
  end
  lines[13] = '013 a book with no title. It breathes.'
  lines[42] = '042 The Answer! Stand right here.'
  lines[97] = '097 Behind the atlas: the golden KEY'
  lines[150] = '150 The secret exit! You made it.'
  return lines
end

local function candle_tick(ctx)
  local S = ctx.state()
  if S.easy or S.obj ~= 1 then
    S.alert = nil
    return
  end
  local burn = S.newbie and 90000 or 45000
  S.candle = S.candle or S.t + burn
  local left = math.ceil((S.candle - S.t) / 1000)
  if left <= 0 then
    ctx.sound 'whoosh'
    ctx.flicker(700, true)
    ctx.set_cursor(1, 0)
    S.candle = S.t + burn
    ctx.say('The candle died. Something cold brushed your neck in the dark... You fled back to shelf 001.', 'VQBad')
    return
  end
  S.alert = { ('🕯 Candle burns: %ds'):format(left), left <= 10 and 'VQBad' or 'VQGold' }
  if left <= 10 then ctx.sound('clock', 950) end
  if left <= 12 and math.random() < 0.05 then ctx.flicker(130, left <= 6) end
end

-- Chapter 7 decree --------------------------------------------------------------------

local decree = {
  '=== DECREE OF THE MOUSE KING ===',
  'Rule 1: doors open with a click.',
  'Rule 2: scrolls must click to read.',
  'Rule 3: click, click, click all day.',
  'ARMOR ARMOR ARMOR ARMOR ARMOR',
  'ARMOR ARMOR ARMOR ARMOR ARMOR',
  'ARMOR ARMOR ARMOR ARMOR ARMOR',
  'Rule 4: keyboards are forbidden.',
}

local function boss_hit(ctx)
  local S = ctx.state()
  S.hp = (S.hp or 4) - 1
  require('vimquest.ui').hurt(S.hp, 4)
end

-- The king counter-attacks with fresh ARMOR until it is shattered
local function boss_tick(ctx)
  local S = ctx.state()
  if S.easy or S.obj > 2 then
    S.alert = nil
    return
  end
  local every = S.newbie and 40000 or 25000
  S.attack = S.attack or S.t + every
  local left = math.ceil((S.attack - S.t) / 1000)
  if left <= 0 then
    if ctx.mode() ~= 'n' then return end
    local lines = ctx.lines()
    local at = #lines
    for i, l in ipairs(lines) do
      if l:find('Rule 4', 1, true) then at = i - 1 end
    end
    ctx.edit(function() api.nvim_buf_set_lines(ctx.buf(), at, at, false, { 'ARMOR ARMOR ARMOR ARMOR ARMOR' }) end)
    S.attack = S.t + every
    ctx.sound 'zap'
    ctx.flicker(250)
    ctx.say('Clickmore casts ARMOR! Another line appears. Hurry!', 'VQBad')
    return
  end
  S.alert = { ('⚡ Clickmore charges a spell: %ds'):format(left), left <= 5 and 'VQBad' or 'VQGold' }
end

-- Chapter 8 the Void --------------------------------------------------------------------

local rooms = {
  {
    '. . . . . T H E   V O I D . . . . .',
    '',
    'You are trapped inside Vim.',
    'Knights who came here never left.',
    'The doors open only for those who',
    'speak the ancient words of leaving.',
    '',
    '      [ THE DOOR OF TRYING ]',
  },
  {
    '. . . . . T H E   V O I D . . . . .',
    '',
    'The door stays shut. The Void hisses:',
    '"You CHANGED something. Vim will not',
    'let you leave and lose your work."',
    'The ! means: I mean it. Throw it away.',
    '',
    '      [ THE DOOR OF FORCE ]',
  },
  {
    '. . . . . T H E   V O I D . . . . .',
    '',
    'The door bursts open! Your changes',
    'are thrown into the dark.',
    'But wise knights KEEP their work:',
    'write it, then quit, all at once.',
    '',
    '      [ THE DOOR OF SAVING ]',
  },
  {
    '. . . . . T H E   V O I D . . . . .',
    '',
    'Saved and free. One door remains.',
    'The oldest knights needed no colon:',
    'two capital letters, in Normal mode.',
    '',
    '',
    '      [ THE LAST DOOR ]',
  },
}

local function void_quit(ctx, bang, how)
  local S = ctx.state()
  if not S or S.finished then return end
  S.void = S.void or {}
  local action = (how == 'wq' and 'wq') or (how == 'zz' and 'zz') or (bang and 'forced') or 'tried'
  local want = ({ 'tried', 'forced', 'wq', 'zz' })[S.obj]
  if action ~= want then
    local need = ({ tried = ':q', forced = ':q!', wq = ':wq', zz = 'ZZ' })[want]
    ctx.sound 'error'
    ctx.say(('That works in real Vim too! But this door only opens for %s.'):format(need), 'VQDim')
    return
  end
  S.void[action] = true
  if action == 'tried' then
    ctx.sound 'error'
    if vim.bo[ctx.buf()].modified then
      ctx.say('E37: No write since last change (add ! to override). Vim refuses to quit: you changed the file and did not save it!', 'VQBad')
    else
      ctx.say('With no changes, :q just works. But the Void keeps changing things, so remember: E37 means unsaved changes.', 'VQBad')
    end
  end
  S.sticky = action == 'tried'
  ctx.flicker(220, true)
  ctx.check()
end

local function void_tick(ctx)
  local S = ctx.state()
  if math.random() < 0.012 then ctx.flicker(160, true) end
  S.alert = { ('🚪 Door %d of 4'):format(math.min(S.obj, 4)), 'VQRuneText' }
end

local function void_setup(ctx)
  local buf = ctx.buf()
  api.nvim_buf_create_user_command(buf, 'VimQuestQuit', function(o)
    local arg = o.args
    void_quit(ctx, o.bang or arg:find('!', 1, true) ~= nil, (arg:gsub('!', '')))
  end, { bang = true, nargs = '?' })
  api.nvim_buf_call(buf, function()
    for _, w in ipairs({ { 'q', 'q' }, { 'quit', 'q' }, { 'qa', 'q' }, { 'qall', 'q' }, { 'wq', 'wq' }, { 'x', 'wq' }, { 'wqa', 'wq' }, { 'xa', 'wq' } }) do
      vim.cmd(("cnoreabbrev <buffer> <expr> %s getcmdtype() ==# ':' && getcmdline() ==# '%s' ? 'VimQuestQuit %s' : '%s'"):format(w[1], w[1], w[2], w[1]))
    end
  end)
  vim.keymap.set('n', 'ZZ', function() void_quit(ctx, false, 'zz') end, { buffer = buf })
  vim.keymap.set('n', 'ZQ', function() void_quit(ctx, true, 'q') end, { buffer = buf })
  ctx.match('VQRuneText', 'T H E   V O I D')
  ctx.match('VQGold', '\\[ .* \\]')
end

-- Chapters ----------------------------------------------------------------------------------

M.chapters = {
  {
    name = 'The Cave of Four Winds',
    music = 'bgm_cave',
    par = 75,
    keys = { '`h` left    `l` right', '`j` down    `k` up', 'Counts: `5l` = 5 steps right' },
    rune = { row = 12, col = 27, letter = 'E', whisper = 'A cold whisper: "Deep in the south of the cave, a dead end glows purple..."', lore = '"Every knight who entered Vim... stayed. Forever."' },
    intro = {
      page('narrator', 'night', 'Long ago, in the kingdom of Textoria, every word lived in peace. Knights edited scrolls at the speed of thought...'),
      page('narrator', 'night', 'Until LORD CLICKMORE, the Mouse King, cursed the land. "From now on," he squeaked, "everyone must CLICK!"'),
      wizard('night', 'Sir Cursor! I am Escarion. The Mouse King sealed the arrow keys - but a true knight moves with four letters on the home row.'),
      wizard('cave', 'Put your right hand on j k l ; - the key with the little bump is j. Now: `l` moves RIGHT. Step toward me!', 'l'),
      wizard('cave', 'Good! `h` moves LEFT. Step back!', 'h'),
      wizard('cave', '`j` moves DOWN. Remember: j has a hook that points down. Press it!', 'j'),
      wizard('cave', '`k` moves UP. Press it!', 'k'),
      wizard('cave', 'Now a knight\'s secret: type a number first to repeat a move. Type 3 then l to take three steps!', '3l'),
      wizard('cave', 'You will be the gold @ in the cave. Collect the 3 gems (*), then leave through the door D. Mouse traps (^) send you back!'),
      page('wizard', 'cave', 'And beware the MOUSE GUARD (M). It wakes when it hears you and hunts you through the dark. If it touches you... RUN.', { fx = 'flicker' }),
      hero('cave', 'Home row, hooks and numbers. And running. To the cave!'),
    },
    outro = {
      wizard('cave', 'Splendid! Your hands never left the home row. That is the first secret of the Vim way.'),
      stranger('cave', 'Psst... knight. Did you see the purple glow in the cave? That was a RUNE. There are seven - one in every land.'),
      stranger('cave', 'Find them all... and I will tell you what the wizard is hiding from you.'),
      hero('cave', 'Who - ? He\'s gone. Escarion, did you see that hooded man?'),
    },
    modifiable = false,
    lines = function()
      local l = vim.deepcopy(maze)
      l[START[1]] = l[START[1]]:gsub('S', ' ')
      return l
    end,
    setup = function(ctx)
      ctx.match('VQWall', '#')
      ctx.match('VQGem', '\\*')
      ctx.match('VQTrap', '\\^')
      ctx.match('VQDoor', 'D')
    end,
    on_move = maze_move,
    hero = true,
    tick = guard_tick,
    objectives = {
      {
        text = 'Collect all 3 gems (*)',
        tip = 'You are the gold @. Press `j` to go down, `l` to go right, `k` up, `h` left. Brown blocks are walls. Try `5j` to move 5 steps at once!',
        start = function(ctx) ctx.set_cursor(START[1], START[2]) end,
        check = function(ctx) return count(ctx.lines(), '%*') == 0 end,
      },
      {
        text = 'Escape through the door D',
        tip = 'The door D is in the bottom-right corner. Use `j` and `l` to get there - and stay away from the M!',
        check = function(ctx)
          local r, c = ctx.cursor()
          return r == DOOR[1] and c == DOOR[2]
        end,
      },
    },
  },
  {
    name = 'Stepping Stones of Wordmere',
    music = 'bgm_river',
    par = 20,
    keys = { '`w` next word   `b` back', '`e` end of word', '`0` line start  `$` line end' },
    rune = { row = 11, col = 38, letter = 'X', whisper = 'A whisper from the water: "Sink to the very bottom of the river... then swim to its far end."', lore = '"Twenty years I have wandered these buffers."' },
    intro = {
      wizard('river', 'Behold Wordmere! Its stepping stones are words, and they sink if you dawdle. Walking letter by letter with l is far too slow.'),
      wizard('river', '`w` leaps to the start of the NEXT word. Leap!', 'w'),
      wizard('river', '`b` leaps BACK one word. Press it!', 'b'),
      wizard('river', '`e` lands on the END of a word. Press it!', 'e'),
      wizard('river', '`$` flies to the END of the line. Hold Shift and press 4!', '$'),
      wizard('river', '`0` (zero) flies back to the START of the line. Press it!', '0'),
      wizard('river', 'Each crossing has a move budget shown in the quest log. Run out and SPLASH - you start that crossing again. Reach each glowing green word!'),
    },
    outro = {
      hero('river', 'Not a single wet boot! Escarion... the hooded man. He was watching us from the reeds.'),
      wizard('river', 'Hooded man? ...There is no one. There has never been anyone. Eyes forward, knight.'),
    },
    modifiable = false,
    lines = {
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
      'reed reed reed reed reed reed FROG reed',
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
      'the river runs to the far shore GOAL',
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
      'HOME is where the knight began',
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
      'the frog sat on a lilypad',
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
      'START one two three four five',
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
    },
    setup = function(ctx) ctx.match('VQWater', '\\~') end,
    objectives = {},
  },
  {
    name = 'The Bug Swarm',
    music = 'bgm_bugs',
    par = 40,
    keys = { '`x` delete one character', '`dd` delete a whole line', '`u` undo   `Ctrl-r` redo' },
    rune = { row = 7, col = 34, letter = 'I', whisper = 'Something whispers: "The scroll\'s final full stop... is not a full stop."', lore = '"The wizard knows the way out. He will not tell you."' },
    intro = {
      page('wizard', 'meadow', 'Disaster! The Mouse King sent BUGS (X) to chew holes in the Royal Scroll, and slimy SLIME lines everywhere!'),
      wizard('meadow', '`x` squashes the one character under your cursor. Squash!', 'x'),
      wizard('meadow', '`dd` deletes the whole line - press d twice, quickly. Try it!', 'dd'),
      wizard('meadow', '`u` is UNDO - your safety net. Broke something? Press u. Try it now!', 'u'),
      wizard('meadow', 'Move onto each red X with h j k l and press x. Then wipe the SLIME lines with dd. Go!'),
    },
    outro = {
      wizard('meadow', 'The scroll is clean again! And you undid that goblin\'s mischief with one key.'),
      hero('meadow', 'Escarion, the hooded man said you are hiding something.'),
      page('wizard', 'meadow', '...Ghost stories. Pay them no mind. Come, the bridge awaits.', { fx = 'flicker' }),
    },
    modifiable = true,
    lines = {
      'Royal Scroll of Textoria',
      'The kingXdom was calm and Xbright.',
      '~~~~ SLIME ~~~~ SLIME ~~~~',
      'Every scroll was wriXtten with love.',
      '~~~~ SLIME ~~~~ SLIME ~~~~',
      '~~~~ SLIME ~~~~ SLIME ~~~~',
      'Then the Mouse King sent his Xbugs.',
    },
    setup = function(ctx)
      ctx.match('VQBug', 'X')
      ctx.match('VQSlime', '.*SLIME.*')
    end,
    objectives = {
      {
        text = 'Squash all 4 bugs X with `x`',
        tip = 'Move onto a red X with `h` `j` `k` `l`, then press `x`. Deleted the wrong letter? Press `u` to undo.',
        check = function(ctx) return eq(no_slime(ctx.lines()), scroll) end,
      },
      {
        text = 'Delete the 3 SLIME lines with `dd`',
        tip = 'Move to any SLIME line with `j` or `k` and press `dd`. Two SLIME lines in a row? `2dd` deletes both!',
        check = function(ctx) return eq(ctx.lines(), scroll) end,
      },
      {
        text = 'A goblin tore out a line! Undo it with `u`',
        tip = 'Press `u` once to undo the goblin\'s change. Pressed it too many times? `Ctrl-r` redoes.',
        start = function(ctx)
          vim.defer_fn(function()
            if not ctx.state() then return end
            ctx.edit(function() api.nvim_buf_set_lines(ctx.buf(), 2, 3, false, {}) end)
            ctx.state().goblin = true
            ctx.sound 'giggle'
            ctx.flicker(200)
            ctx.say('Hehehe! A goblin ripped out line 3 of the scroll!', 'VQBad')
          end, 600)
        end,
        check = function(ctx) return ctx.state().goblin and eq(ctx.lines(), scroll) end,
      },
    },
  },
  {
    name = 'The Broken Bridge',
    music = 'bgm_bridge',
    par = 70,
    keys = { '`i` insert before cursor', '`a` append after cursor', '`A` append at end of line', '`o` open new line below', '`Esc` back to Normal mode' },
    rune = { row = 1, col = 24, letter = 'T', whisper = 'The wind howls: "Where the canyon ends... something remembers."', lore = '"Ask him how to LEAVE Vim. Watch his face."' },
    intro = {
      wizard('canyon', 'The bridge over the canyon is full of holes. To fix words you must TYPE - and typing needs INSERT mode.'),
      wizard('canyon', '`i` enters Insert mode. Press it!', 'i'),
      wizard('canyon', 'In Insert mode your letters become text. To get back, press `Esc` - the key in the top-left corner. Press it!', '<Esc>'),
      wizard('canyon', '`a` also enters Insert mode, but AFTER the cursor. Press it!', 'a'),
      wizard('canyon', 'And back to Normal mode with `Esc`. Always Esc when you are done typing!', '<Esc>'),
      wizard('canyon', '`A` (Shift + a) types at the END of the line. `o` opens a fresh line below. Press `o`!', 'o'),
      wizard('canyon', 'Esc, one more time. It will become a reflex.', '<Esc>'),
    },
    outro = {
      wizard('canyon', 'A fine bridge! You switched modes like a true knight.'),
      page('stranger', 'canyon', 'Four runes, knight. Ask the wizard how to LEAVE Vim. Ask him... and watch his face.', { fx = 'flicker glitch' }),
    },
    modifiable = true,
    lines = { 'Th bridge over the canyon', 'was built by brave kights' },
    objectives = {
      {
        text = 'Line 1: fix "Th" into "The"',
        tip = 'Press `l` to move onto the "h" of Th. Press `a`, type the letter e, then press `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and ctx.line(1) == bridge[1] end,
      },
      {
        text = 'Line 2: fix "kights" into "knights"',
        tip = 'Press `j` to go down. Move onto the "i" of kights. Press `i`, type n, then `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and ctx.line(2):find('brave knights', 1, true) ~= nil end,
      },
      {
        text = 'Add a comma at the end of line 2',
        tip = 'Press `A` (it jumps to the end and starts typing), type a comma, then `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and ctx.line(2) == bridge[2] end,
      },
      {
        text = 'Add line 3: who never used a mouse.',
        tip = 'Press `o` to open a new line below, type: who never used a mouse. then press `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and eq(vim.tbl_map(vim.trim, ctx.lines()), bridge) end,
      },
    },
  },
  {
    name = 'The Spell Tower',
    music = 'bgm_tower',
    par = 30,
    keys = { '`*` search word under cursor', '`n` next match', '`ciw` change inner word', '`.` repeat last change', '`dw` delete a word' },
    rune = { row = 1, col = 28, letter = 'V', whisper = 'Ink seeps from the wall: "The spell begins with a colon... at the end of the first line."', lore = '"Colon. Q. The two keys he fears most."' },
    intro = {
      wizard('tower', 'The Mouse King wrote a cursed spell that worships the mouse. We shall rewrite it to honor vim!'),
      wizard('tower', 'First, mark your target. `*` (Shift + 8) searches for the word under your cursor. Press it!', '*'),
      wizard('tower', 'Now `ciw` - Change Inner Word: it deletes the word under the cursor so you can type a new one. Type c, then i, then w!', 'ciw'),
      wizard('tower', '`n` jumps to the NEXT match of your search - that is why we pressed * first. Press it!', 'n'),
      wizard('tower', '`.` (the period key) REPEATS your last change. The most powerful key in Vim! Press it!', '.'),
      wizard('tower', 'The knight\'s dance: on "mouse" press *, then ciw, type vim, Esc. Then n . n . and the spell is broken!'),
    },
    outro = {
      wizard('tower', 'n . n . - the dance of a true knight! The dot will save you thousands of keystrokes.'),
      hero('tower', 'Escarion... how does a knight LEAVE Vim?'),
      page('wizard', 'tower', '...Leave? Why would anyone want to leave? We have so much more to learn. Come. The library.', { fx = 'flicker glitch' }),
    },
    modifiable = true,
    lines = {
      'The cursed spell of the king:',
      'the mouse is wise, the mouse is strong,',
      'bow to the mouse or be gone.',
      'the evil evil king laughs.',
    },
    setup = function(ctx) ctx.match('VQCurse', '\\<mouse\\>') end,
    objectives = {
      {
        text = 'Press `*` on a "mouse", then `ciw` it into "vim"',
        tip = 'Press `w` to move onto "mouse". Press `*`, then `ciw`, type vim, and press `Esc`.',
        start = function(ctx) ctx.set_cursor(2, 0) end,
        check = function(ctx)
          local l = ctx.lines()
          return ctx.mode() == 'n' and count(l, '%f[%w]mouse%f[%W]') == 2 and count(l, '%f[%w]vim%f[%W]') == 1
        end,
      },
      {
        text = 'Banish the other two with `n` and `.`',
        tip = 'Press `n` to jump to the next mouse, then `.` to repeat your change. Again: `n` `.` (No `*` yet? Type `/mouse` and `Enter` first.)',
        -- n only repeats a search, so warn if the player skipped * before ciw
        start = function(ctx)
          if not vim.fn.getreg('/'):find 'mouse' then ctx.say('No search yet, so n has nothing to find! Type /mouse and Enter, then . to repeat your change.', 'VQBad') end
        end,
        check = function(ctx) return ctx.mode() == 'n' and eq({ ctx.line(2), ctx.line(3) }, { spell[2], spell[3] }) end,
      },
      {
        text = 'Line 4: delete the extra "evil" with `dw`',
        tip = 'Go to line 4 with `j`. Press `w` to reach the first "evil", then `dw`.',
        check = function(ctx) return eq(ctx.lines(), spell) end,
      },
    },
  },
  {
    name = 'The Library of Echoes',
    music = 'bgm_library',
    par = 22,
    keys = { '`/text` `Enter` search', '`n` next   `N` previous', '`G` last line   `gg` first', '`42G` go to line 42' },
    rune = { row = 13, col = 0, letter = 'I', whisper = 'A book falls from a shelf by itself. On its spine: "Shelf thirteen. Unlucky for some."', lore = '"One more after this... and the truth is yours."' },
    intro = {
      wizard('library', 'The Library of Echoes: 150 shelves. Scrolling with j would take until next Tuesday.'),
      wizard('library', '`/` starts a search - it is the key just left of the right Shift. Press it!', '/'),
      wizard('library', '`G` (Shift + g) jumps to the LAST line. Press it!', 'G'),
      wizard('library', '`gg` (g twice) jumps to the FIRST line. Press it!', 'gg'),
      wizard('library', 'Type a number before G to jump to that exact line. Type 4, 2, then Shift + g!', '42G'),
      page('wizard', 'library', 'Find the golden KEY: type /KEY and press Enter. Hurry - the candle burns only so long. And if you hear whispers here... do NOT listen.', { fx = 'flicker' }),
    },
    outro = {
      hero('library', 'The golden KEY! To the castle of Lord Clickmore!'),
      page('stranger', 'library', 'Six runes... One more, knight. In the throne room. Then come and find me.', { fx = 'flicker glitch' }),
    },
    modifiable = false,
    lines = library,
    setup = function(ctx) ctx.match('VQGold', 'KEY') end,
    tick = candle_tick,
    objectives = {
      {
        text = 'Find the golden KEY',
        tip = 'Type `/KEY` and press `Enter`. Use capital letters - a lowercase search for key also finds monkeys and donkeys!',
        start = function(ctx) ctx.set_cursor(1, 0) end,
        check = function(ctx)
          local r, c = ctx.cursor()
          local a, b = word_range(ctx.line(97), 'KEY')
          return r == 97 and c >= a and c <= b
        end,
      },
      {
        text = 'Reach the secret exit on the last line',
        tip = 'Press `G` (Shift + g) to jump to the very end.',
        check = function(ctx) return ctx.cursor() == api.nvim_buf_line_count(ctx.buf()) end,
      },
      {
        text = 'Return to the first line',
        tip = 'Press `gg` to jump to the top.',
        check = function(ctx) return ctx.cursor() == 1 end,
      },
      {
        text = 'Stand on shelf 42, the Answer',
        tip = 'Type `42G` - or type `:` then 42 and `Enter`.',
        check = function(ctx) return ctx.cursor() == 42 end,
      },
    },
  },
  {
    name = 'The Throne of Lord Clickmore',
    music = 'bgm_throne',
    par = 60,
    keys = { '`:%s/old/new/g` replace all', '`V` select lines, `j` grow', '`d` delete selection', '`cw` change word', '`:w` save the file' },
    rune = { row = 1, col = 31, letter = 'M', whisper = 'The torches gutter: "Even the king\'s banner hides a secret... at its very end."', lore = '"E-X-I-T-V-I-M. Now you know. Meet me in the Void."' },
    intro = {
      king('throne', 'SO! The little knight learned a few keys. But my Royal Decree is ETERNAL! Click! Click! CLICK!'),
      wizard('throne', 'His power lives in the decree. `:` (Shift + ;) opens the command line where knights cast spells. Press it!', ':'),
      wizard('throne', '`V` (Shift + v) selects whole lines. Press it!', 'V'),
      wizard('throne', 'Cast :%s/click/press/g to replace every click. Select the ARMOR with V and j, then d. Then save with :w!'),
      page('king', 'throne', 'Every few seconds I summon MORE ARMOR! You will never break through! SQUEAK!', { fx = 'flicker' }),
    },
    outro = {
      king('throne', 'Nooo... my beautiful clicks... I\'ll be back... with a TRACKPAD!'),
      page('wizard', 'victory', 'The decree is broken! You moved, searched, changed, repeated, replaced and saved. ACT I is complete, Vim Knight!'),
      page('king', 'throne', 'Hah! You think this is over? Catch me in the SHADOW REALM, knight! SQUEAK!', { fx = 'flicker' }),
      hero('throne', 'He jumped into the mirror behind the throne! After him!'),
    },
    victory = true,
    modifiable = true,
    buftype = 'acwrite',
    file = 'royal_decree.txt',
    lines = decree,
    setup = function(ctx)
      ctx.match('VQCurse', 'click')
      ctx.match('VQArmor', 'ARMOR')
    end,
    on_write = function(ctx)
      local S = ctx.state()
      if S.obj == #S.L.objectives then
        S.saved = true
      else
        ctx.say('The decree is still cursed! Finish the other tasks before you seal it with :w', 'VQBad')
      end
    end,
    on_objective = boss_hit,
    tick = boss_tick,
    objectives = {
      {
        text = 'Replace every "click" with "press"',
        tip = 'Type `:%s/click/press/g` and press `Enter`. (% means the whole file, g means every match on a line.)',
        start = function(ctx) ctx.set_cursor(1, 0) end,
        check = function(ctx) return count(ctx.lines(), 'click') == 0 and count(ctx.lines(), 'press') >= 5 end,
      },
      {
        text = 'Shatter all the ARMOR lines with `V`',
        tip = 'Move to the first ARMOR line with `j`. Press `V`, then `j` until every ARMOR line is selected, then `d`.',
        check = function(ctx) return count(ctx.lines(), 'ARMOR') == 0 and #ctx.lines() == 5 end,
      },
      {
        text = 'Change "forbidden" into "beloved"',
        tip = 'Move to the start of "forbidden" (`$` then `b`), press `cw`, type beloved, then `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and ctx.line(5) == 'Rule 4: keyboards are beloved.' end,
      },
      {
        text = 'Seal the new decree with `:w`',
        tip = 'Type `:w` and press `Enter` to write (save) the file.',
        check = function(ctx) return ctx.state().saved end,
      },
    },
  },
  {
    name = 'The Void Beyond',
    music = 'bgm_void',
    secret = true,
    par = 30,
    keys = { '`:q` quit', '`:q!` quit, throw away changes', '`:wq` write and quit', '`ZZ` write and quit' },
    intro = {
      page('hero', 'void', 'E... X... I... T... V... I... M. The moment I read the runes aloud, the ground vanished beneath my feet...', { cast = { 'hero' }, fx = 'scare flicker' }),
      stranger('void', 'At last. Someone who can read the runes. Do not be afraid, knight.'),
      stranger('void', 'I was the First Knight. Twenty years ago I opened Vim... and I never found the way out.'),
      stranger('void', 'Escarion knew the words of leaving. He hid them, so no knight would ever leave Textoria. So no one would ever leave HIM.'),
      page('hero', 'void', 'Then teach me the words. We leave together.', { cast = { 'hero', 'stranger' } }),
      page('stranger', 'void', 'Every word of leaving begins with the colon. Press it. Feel its power.', { press = ':', fx = 'flicker' }),
      stranger('void', 'Four doors. Four words. The first door is simple: just TRY to leave. Type :q and press Enter...'),
    },
    outro = {
      stranger('void', 'The last door is open... For the first time in twenty years, I can go home.', 'flicker'),
      page('wizard', 'void', 'So. You found the words of leaving. I... I only wanted you to stay. Everyone always leaves.', { fx = 'flicker' }),
      hero('void', 'Knights must be free to leave, Escarion. That is exactly why they come back.'),
      page('narrator', 'victory', 'TRUE ENDING. The First Knight walked out into the sunlight. Escarion now teaches :q at every school in Textoria.', { cast = { 'hero', 'wizard' } }),
      page('narrator', 'victory', 'And whenever someone, somewhere, asks "how do I exit Vim?"... a knight answers. Thank you for playing.', { cast = { 'hero', 'wizard' } }),
    },
    modifiable = true,
    buftype = 'acwrite',
    file = 'the_void.txt',
    start_modified = true,
    lines = rooms[1],
    setup = void_setup,
    tick = void_tick,
    on_write = function(ctx) ctx.say('Saved... but you are still here. Saving alone opens no doors.', 'VQDim') end,
    on_objective = function(ctx)
      local S = ctx.state()
      if rooms[S.obj] then
        ctx.sound 'door'
        ctx.edit(function() api.nvim_buf_set_lines(ctx.buf(), 0, -1, false, rooms[S.obj]) end)
        vim.bo[ctx.buf()].modified = true
      end
    end,
    objectives = {
      {
        text = 'Try to leave with `:q`',
        tip = 'Type `:q` and press `Enter`. Then read the bottom of the quest log...',
        check = function(ctx) return (ctx.state().void or {}).tried end,
      },
      {
        text = 'Force your way out with `:q!`',
        tip = 'The ! means "I really mean it - throw away my changes". Type `:q!` and press `Enter`.',
        check = function(ctx) return (ctx.state().void or {}).forced end,
      },
      {
        text = 'Save AND quit with `:wq`',
        tip = '`:wq` writes the file, then quits - all in one. Type `:wq` and press `Enter`.',
        check = function(ctx) return (ctx.state().void or {}).wq end,
      },
      {
        text = 'The last door: `ZZ`',
        tip = 'In Normal mode, press `ZZ` - hold Shift and press z twice. No colon needed!',
        check = function(ctx) return (ctx.state().void or {}).zz end,
      },
    },
  },
}

-- Act II slots in before the secret Void chapter
for i, ch in ipairs(require 'vimquest.act2' { page = page, wizard = wizard, hero = hero, king = king, stranger = stranger, eq = eq, count = count }) do
  table.insert(M.chapters, 7 + i, ch)
end

-- Bonus chapters about real-world Neovim come after the story, always unlocked
vim.list_extend(M.chapters, require 'vimquest.bonus' { page = page, wizard = wizard, hero = hero, stranger = stranger })

-- Chapter 2 objectives: reach a target word within a move budget
local function hop(row, from_end, word, budget, text, tip, at_end)
  local function range(ctx)
    local a, b = word_range(ctx.line(row), word)
    if at_end then a = b end
    return a, b
  end
  return {
    text = text,
    tip = tip,
    budget = budget,
    fail = 'SPLASH! The stone sank. Back to the start of this crossing - try fewer keys.',
    start = function(ctx)
      ctx.set_cursor(row, from_end and #ctx.line(row) - 1 or 0)
      local a, b = range(ctx)
      mark(ctx, row, a, b)
    end,
    check = function(ctx)
      local r, c = ctx.cursor()
      local a, b = range(ctx)
      local ok = r == row and c >= a and c <= b
      if ok then mark(ctx) end
      return ok
    end,
  }
end

M.chapters[2].objectives = {
  hop(2, false, 'FROG', 7, 'Leap to FROG with `w`', 'Press `w` six times to leap word by word - or type `6w` for one big leap!'),
  hop(4, false, 'GOAL', 2, 'Fly to GOAL at the end with `$`', 'Press `$` (Shift + 4) to jump to the end of the line in one key.'),
  hop(6, true, 'HOME', 2, 'Fly back HOME with `0`', 'Press `0` (zero) to jump to the very start of the line.'),
  hop(8, false, 'lilypad', 7, 'Land on the last letter of lilypad with `e`', 'Press `e` six times - each one hops to the END of a word. Or `6e`!', true),
  hop(10, true, 'START', 7, 'Leap back to START with `b`', 'Press `b` six times to leap back word by word - or `6b`!'),
}

return M
