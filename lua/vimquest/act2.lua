-- Act II, the Shadow Realm: chapters covering the rest of vimtutor
local api = vim.api

return function(H)
  local page, wizard, hero, king, stranger, eq, count = H.page, H.wizard, H.hero, H.king, H.stranger, H.eq, H.count

  local function find_line(ctx, text)
    for i, l in ipairs(ctx.lines()) do
      if l == text then return i end
    end
  end

  local function cursor_on(ctx, row, word)
    local r, c = ctx.cursor()
    local s = ctx.line(row):find(word, 1, true)
    return r == row and s ~= nil and c >= s - 1 and c <= s - 2 + #word
  end

  local function at(ctx, row, col)
    local r, c = ctx.cursor()
    return r == row and c == col
  end

  local function last_col(ctx, row) return #ctx.line(row) - 1 end

  -- Chapter 8: the Hall of Mirrors ----------------------------------------------------

  local twin_ns = api.nvim_create_namespace 'vimquest_twin'

  -- Your reflection walks the same line, mirrored; now and then its eyes turn red
  local function mirror_twin(ctx)
    local S = ctx.state()
    api.nvim_buf_clear_namespace(S.buf, twin_ns, 0, -1)
    local r, c = ctx.cursor()
    local tc = #ctx.line(r) - 1 - c
    if tc >= 0 and tc ~= c then
      local evil = not S.calm and S.t % 4000 < 200
      api.nvim_buf_set_extmark(S.buf, twin_ns, r - 1, tc, { end_col = tc + 1, hl_group = evil and 'VQGuard' or 'VQTwin', priority = 380 })
    end
    -- Tell players once that the purple shape is an easter egg, not a rune to collect
    if not S.twin_told and S.keys > 0 then
      S.twin_told = true
      ctx.say('That purple shape is just your reflection. No need to catch it, knight!', 'VQRuneText')
    elseif not S.twin_touched and tc >= 0 and math.abs(tc - c) <= 1 then
      S.twin_touched = true
      ctx.say('You touch the glass... it is only your reflection. It mirrors you; it cannot be caught.', 'VQRuneText')
    end
  end

  local mirrors = {
    name = 'The Hall of Mirrors',
    music = 'bgm_mirrors',
    par = 60,
    keys = { '`yy` copy line  `yw` copy word', '`p` paste   `r` replace letter', '`R` overwrite  `O` line above', '`U` undo the whole line' },
    intro = {
      wizard('mirrors', 'Clickmore escaped through a mirror into the Shadow Realm! This hall copies everything... and every crack must be mended.'),
      wizard('mirrors', 'In Vim, copying is called YANKING. `yy` yanks the whole line. Press y twice!', 'yy'),
      wizard('mirrors', '`p` PUTS what you yanked, right after the cursor. Paste it!', 'p'),
      wizard('mirrors', '`yw` yanks just one word. Press y, then w!', 'yw'),
      wizard('mirrors', '`r` replaces ONE letter: press r, then the new letter. Try r then o!', 'ro'),
      wizard('mirrors', '`R` (Shift + r) is Replace mode: you type OVER letters instead of pushing them aside. Press R, then Esc to leave it.', 'R<Esc>'),
      wizard('mirrors', '`O` (Shift + o) opens a new line ABOVE you - the twin of o. Press it!', 'O'),
      wizard('mirrors', '`U` (Shift + u) undoes EVERY change on a line at once. Press it!', 'U'),
      stranger('mirrors', 'Careful, knight. The mirrors here remember faces. The purple one walking beside you... is not your reflection.'),
    },
    outro = {
      hero('mirrors', 'The password was ESCAPE. Why would a mirror know that word?'),
      stranger('mirrors', 'Because I scratched it there. Twenty years ago. From the other side of the glass.'),
    },
    modifiable = true,
    lines = {
      '~*~ THE HALL OF MIRRORS ~*~',
      'The mirrxr shows a brave knigxt.',
      '',
      'BANNER OF LIGHT',
      '',
      'The never lies.',
      '',
      'Password: ??????',
    },
    setup = function(ctx)
      ctx.match('VQBug', 'mirr\\zsx')
      ctx.match('VQBug', 'knig\\zsx')
      ctx.match('VQGold', 'BANNER OF LIGHT')
      ctx.match('VQCurse', '?')
    end,
    tick = mirror_twin,
    objectives = {
      {
        text = 'Mend the 2 cracked letters (red x) with `r`',
        tip = 'Move onto the red x in "mirrxr" and press `r` then o. On the x in "knigxt", press `r` then h.',
        start = function(ctx) ctx.set_cursor(2, 0) end,
        check = function(ctx) return find_line(ctx, 'The mirror shows a brave knight.') ~= nil end,
      },
      {
        text = 'Make 3 BANNER lines in a row: `yy` then `p`',
        tip = 'Go to the BANNER line, press `yy` to yank it, then `p` twice (or `2p`) to paste two copies.',
        check = function(ctx)
          local run, best = 0, 0
          for _, l in ipairs(ctx.lines()) do
            run = l == 'BANNER OF LIGHT' and run + 1 or 0
            best = math.max(best, run)
          end
          return best == 3 and count(ctx.lines(), 'BANNER OF LIGHT') == 3
        end,
      },
      {
        text = 'Yank "mirror" with `yw`, put it in "The never lies."',
        tip = 'On line 2 put the cursor on the m of "mirror", press `yw`. Go to "The never lies.", stand on the space after The, press `p`.',
        check = function(ctx) return find_line(ctx, 'The mirror never lies.') ~= nil end,
      },
      {
        text = 'Above the banners, add: LONG LIVE THE KNIGHT',
        tip = 'Go to the first BANNER line and press `O` - a line opens ABOVE it. Type LONG LIVE THE KNIGHT, then `Esc`.',
        check = function(ctx)
          local i = find_line(ctx, 'BANNER OF LIGHT')
          return ctx.mode() == 'n' and i ~= nil and i > 1 and vim.trim(ctx.line(i - 1)):upper() == 'LONG LIVE THE KNIGHT'
        end,
      },
      {
        text = 'Crack the password: type ESCAPE over ?????? with `R`',
        tip = 'Stand on the first ?, press `R`, type ESCAPE - each letter replaces one ?. Then `Esc`.',
        check = function(ctx) return ctx.mode() == 'n' and find_line(ctx, 'Password: ESCAPE') ~= nil end,
      },
      {
        text = 'Mirror test: break "The mirror never lies." and fix it with `U`',
        tip = 'On that line press `x` three times to break it, then `U` (Shift + u) to undo ALL of it at once.',
        check = function(ctx)
          local S = ctx.state()
          local whole = find_line(ctx, 'The mirror never lies.') ~= nil
          if not whole then S.mirror_broken = true end
          return S.mirror_broken and whole and ctx.typed 'U'
        end,
      },
    },
  }

  -- Chapter 9: the Clockwork Tower --------------------------------------------------------

  local function midnight(ctx)
    local S = ctx.state()
    if S.easy then
      S.alert = nil
      return
    end
    local every = S.newbie and 90000 or 60000
    S.midnight = S.midnight or S.t + every
    local left = math.ceil((S.midnight - S.t) / 1000)
    if left <= 0 then
      S.midnight = S.t + every
      ctx.sound 'bong'
      ctx.flicker(450, true)
      ctx.say('BONG... BONG... Midnight. Something just walked past you on the stairs.', 'VQBad')
      return
    end
    S.alert = { ('🕰 Midnight in %ds'):format(left), left <= 10 and 'VQBad' or 'VQDim' }
    if left <= 10 then ctx.sound('clock', 950) end
  end

  local clock = {
    name = 'The Clockwork Tower',
    music = 'bgm_clock',
    par = 45,
    keys = { '`Ctrl-g` where am I?', '`?` search up  `n` again  `N` reverse', '`%` matching bracket', '`Ctrl-o` back  `Ctrl-i` forward' },
    intro = {
      wizard('clock', 'Clickmore climbed the Clockwork Tower. Its stairs loop back on themselves - lose your place here and you are lost forever.'),
      wizard('clock', '`Ctrl-g` tells you where you are: the file, the line, how far through. Hold Ctrl and press g!', '<C-g>'),
      wizard('clock', '`?` searches BACKWARDS - upward. It is Shift + /. Press it!', '?'),
      wizard('clock', 'After a search, `n` repeats it the same way and `N` (Shift + n) goes the OTHER way. Press N!', 'N'),
      wizard('clock', '`%` (Shift + 5) jumps from a bracket ( to its matching partner ). Press it!', '%'),
      wizard('clock', '`Ctrl-o` jumps BACK to where you were before a jump. Hold Ctrl and press o!', '<C-o>'),
      wizard('clock', '`Ctrl-i` jumps forward again. In your terminal it is the same key as `Tab`. Press Tab!', '<Tab>'),
      page('wizard', 'clock', 'One more thing. The tower strikes midnight every minute. Nobody knows what walks the stairs when it does.', { fx = 'flicker' }),
    },
    outro = {
      hero('clock', 'Backwards, forwards, matching brackets... I could never get lost now.'),
      wizard('clock', 'No. Not like... some knights did.'),
      page('hero', 'clock', 'Some knights? Escarion, what knights?', { fx = 'flicker' }),
    },
    modifiable = false,
    lines = {
      '=== THE CLOCKWORK TOWER ===',
      'GEAR of the first hour',
      'tick tock tick tock',
      'the stairs go round and round',
      'tick tock tick tock',
      'GEAR of the second hour',
      'the stairs go up and down',
      'tick tock tick tock',
      'GEAR of the third hour',
      'tick tock tick tock',
      '(begin the great machine',
      '  (spin (the small) wheels)',
      '  (wind the spring)',
      'end the great machine)',
      'tick tock tick tock',
      'the bottom of the tower',
    },
    setup = function(ctx)
      ctx.match('VQGold', 'GEAR')
      ctx.match('VQRuneText', '[()]')
    end,
    tick = midnight,
    poll = true,
    objectives = {
      {
        text = 'Ask the tower where you are: `Ctrl-g`',
        tip = 'Hold Ctrl and press g. The bottom line shows the file name, the number of lines and how far through you are.',
        start = function(ctx) ctx.set_cursor(16, 0) end,
        check = function(ctx) return ctx.typed '<C-G>' end,
      },
      {
        text = 'Search UP for the nearest GEAR: `?GEAR`',
        tip = 'Type `?GEAR` and press `Enter`. ? searches upward from where you stand. (/ would wrap around to the wrong GEAR!)',
        check = function(ctx) return cursor_on(ctx, 9, 'GEAR') end,
      },
      {
        text = 'Keep climbing with `n`',
        tip = '`n` repeats your search in the same direction - still upward.',
        check = function(ctx) return cursor_on(ctx, 6, 'GEAR') end,
      },
      {
        text = 'Reverse direction with `N`',
        tip = '`N` (Shift + n) repeats the search the OTHER way - back down.',
        check = function(ctx) return cursor_on(ctx, 9, 'GEAR') and ctx.typed 'N' end,
      },
      {
        text = 'Leap across the great machine with `%`',
        tip = 'You are on the ( that starts line 11. Press `%` (Shift + 5) to jump to its matching ).',
        start = function(ctx) ctx.set_cursor(11, 0) end,
        check = function(ctx) return at(ctx, 14, last_col(ctx, 14)) end,
      },
      {
        text = 'Jump back where you were: `Ctrl-o`',
        tip = 'Hold Ctrl and press o. You fly back to the (.',
        check = function(ctx) return at(ctx, 11, 0) and ctx.typed '<C-O>' end,
      },
      {
        text = 'And forward again: `Ctrl-i` (or `Tab`)',
        tip = 'Hold Ctrl and press i - in most terminals that is the same as the Tab key.',
        check = function(ctx) return at(ctx, 14, last_col(ctx, 14)) and ctx.typed '<Tab>' end,
      },
    },
  }

  -- Chapter 10: the Rune Forge ------------------------------------------------------------

  local forge = {
    name = 'The Rune Forge',
    music = 'bgm_forge',
    par = 55,
    keys = { 'verb + motion: `d` delete `c` change', '`d$` to line end  `d2w` 2 words', '`ce` change to word end', '`c$` change to line end  `Ctrl-r` redo' },
    intro = {
      page('narrator', 'forge', 'Deep beneath the tower burns the Rune Forge, where the grammar of Vim was born: a VERB, then a MOTION.'),
      wizard('forge', '`d` is the verb DELETE. `$` is the motion END OF LINE. Together: d$ deletes to the end of the line. Press d then $!', 'd$'),
      wizard('forge', 'Put a number in the middle: `d2w` deletes TWO words. Press d, 2, w!', 'd2w'),
      wizard('forge', '`c` is the verb CHANGE. `ce` changes to the end of a word. Press c then e!', 'ce'),
      wizard('forge', '`c$` changes everything to the end of the line. Press c then $!', 'c$'),
      wizard('forge', 'And if you undo too far with u, `Ctrl-r` REDOES it. Hold Ctrl and press r!', '<C-r>'),
      stranger('forge', 'Forge your name into the steel, knight. Mine is still in there... under twenty years of rust.'),
    },
    outro = {
      wizard('forge', 'Verb, number, motion. You no longer press keys, knight - you SPEAK Vim.'),
      stranger('forge', 'A fine name. Remember it. In the Void, names are all you have left.'),
    },
    modifiable = true,
    lines = {
      '=== THE RUNE FORGE ===',
      'The anvil rings true ~~~CURSED SLAG~~~',
      'the the the hammer sings',
      'the hammzqx glows red',
      'Forged by: ????????',
    },
    setup = function(ctx)
      ctx.match('VQBug', '\\~\\~\\~CURSED SLAG\\~\\~\\~')
      ctx.match('VQBug', 'zqx')
      ctx.match('VQCurse', '?')
    end,
    on_objective = function(ctx) ctx.sound 'clang' end,
    objectives = {
      {
        text = 'Line 2: burn off the cursed slag with `d$`',
        tip = 'Your cursor is right after "true". Press `d` then `$` (Shift + 4). Bonus: `D` does the same!',
        start = function(ctx) ctx.set_cursor(2, 20) end,
        check = function(ctx) return ctx.line(2) == 'The anvil rings true' end,
      },
      {
        text = 'Line 3: delete the extra "the the" with `d2w`',
        tip = 'You are on the first "the". Press `d` `2` `w` to delete two words at once.',
        start = function(ctx) ctx.set_cursor(3, 0) end,
        check = function(ctx) return ctx.line(3) == 'the hammer sings' end,
      },
      {
        text = 'Line 4: fix "hammzqx" with `ce`',
        tip = 'You are on the z. Press `ce`, type er, then `Esc`.',
        start = function(ctx) ctx.set_cursor(4, 8) end,
        check = function(ctx) return ctx.mode() == 'n' and ctx.line(4) == 'the hammer glows red' end,
      },
      {
        text = 'Line 5: forge YOUR name with `c$`',
        tip = 'You are on the first ?. Press `c$`, type your name, then `Esc`.',
        start = function(ctx) ctx.set_cursor(5, 11) end,
        check = function(ctx)
          local l = ctx.line(5)
          return ctx.mode() == 'n' and l:sub(1, 11) == 'Forged by: ' and not l:find('?', 1, true) and #vim.trim(l) > 11
        end,
      },
      {
        text = 'Undo your name with `u`, bring it back with `Ctrl-r`',
        tip = 'Press `u` - your name vanishes! Then hold Ctrl and press r to redo it.',
        start = function(ctx)
          ctx.state().snap = ctx.lines()
          ctx.state().undone = false
        end,
        check = function(ctx)
          local S = ctx.state()
          local same = eq(ctx.lines(), S.snap)
          if not same then S.undone = true end
          return S.undone and same and ctx.typed '<C-R>'
        end,
      },
    },
  }

  -- Chapter 11: the Echo Caverns, boss fight with the Trackpad Golem ----------------------------------

  local function golem_hit(ctx)
    local S = ctx.state()
    S.hp = (S.hp or 4) - 1
    require('vimquest.ui').hurt(S.hp, 4, 'Trackpad Golem')
  end

  local feast = { 'eat the bread', 'the bread is old', "Sir cheese is the cat's name", 'throw the bread away' }

  local echo = {
    name = 'The Echo Caverns',
    music = 'bgm_golem',
    par = 110,
    keys = { '`:s/old/new` first match', '`:s/old/new/g` whole line', '`:5,7s/old/new/g` lines 5-7', '`:%s/old/new/gc` ask each time' },
    intro = {
      king('echo', 'SQUEAK! I told you I would be back! Behold my TRACKPAD GOLEM! Every word in these caverns echoes MY rules!'),
      wizard('echo', 'Substitution, knight - but with precision. `:s/old/new` changes only the FIRST match on the current line. Press the colon to begin!', ':'),
      wizard('echo', 'Add /g to change every match on the line. Put line numbers in front, like :5,7s, to change only those lines.'),
      wizard('echo', 'And /gc asks before EACH change: press y to accept, n to skip. Careful aim beats brute force!'),
      page('king', 'echo', 'My golem has FOUR hit points! You will never... wait, what is your keyboard doing?', { fx = 'flicker' }),
    },
    outro = {
      king('echo', 'My golem! Melted into... a regular mouse pad! This is not over, knight!'),
      wizard('echo', 'He fled into the Archive of Worlds. After him!'),
    },
    modifiable = true,
    lines = {
      '=== THE ECHO CAVERNS ===',
      'squeak squeak goes the golem',
      'squeak squeak squeak all night',
      "-- the golem's spell --",
      'the mouse rules the cave',
      'the mouse rules the stars',
      'the mouse rules the knights',
      '-- end of spell --',
      '(but the mouse is just a pet)',
      'eat the cheese',
      'the cheese is old',
      "Sir cheese is the cat's name",
      'throw the cheese away',
    },
    setup = function(ctx)
      ctx.match('VQCurse', 'squeak')
      ctx.match('VQCurse', 'mouse')
      ctx.match('VQGold', 'cheese')
    end,
    on_objective = golem_hit,
    objectives = {
      {
        text = 'Line 2: change only the FIRST squeak: `:s/squeak/speak`',
        tip = 'You are on line 2. Type `:s/squeak/speak` and press `Enter`. Only the first match changes!',
        start = function(ctx) ctx.set_cursor(2, 0) end,
        check = function(ctx)
          if ctx.line(2) == 'speak speak goes the golem' then ctx.say('Too much! Press u. Without /g only the FIRST match changes.', 'VQBad') end
          return ctx.line(2) == 'speak squeak goes the golem'
        end,
      },
      {
        text = 'Line 3: change EVERY squeak: `:s/squeak/speak/g`',
        tip = 'Press `j` to go to line 3. Type `:s/squeak/speak/g` and `Enter`.',
        check = function(ctx) return ctx.line(3) == 'speak speak speak all night' end,
      },
      {
        text = 'Lines 5-7 only: mouse becomes keyboard',
        tip = 'Type `:5,7s/mouse/keyboard/g` and `Enter`. 5,7 is a RANGE of lines. Line 9 is a pet mouse - leave it alone!',
        check = function(ctx)
          if not ctx.line(9):find('mouse', 1, true) then ctx.say('Oh no, you changed the pet mouse on line 9! Press u and use the range 5,7.', 'VQBad') end
          for i = 5, 7 do
            if not ctx.line(i):find('keyboard', 1, true) then return false end
          end
          return ctx.line(9):find('mouse', 1, true) ~= nil
        end,
      },
      {
        text = 'Every cheese becomes bread - except Sir cheese the cat',
        tip = 'Type `:%s/cheese/bread/gc` and `Enter`. At each match press y to replace or n to skip. Skip the cat!',
        check = function(ctx)
          if ctx.line(12):find('bread', 1, true) then ctx.say("You turned the cat into bread! Press u and try again with /gc - answer n for the cat's name.", 'VQBad') end
          return eq(vim.list_slice(ctx.lines(), 10, 13), feast)
        end,
      },
    },
  }

  -- Chapter 12: the Archive of Worlds, real files in a sandbox folder -------------------------------

  local archive_dir = vim.fs.joinpath(vim.fn.stdpath 'data', 'vimquest', 'archive')
  local function apath(f) return vim.fs.joinpath(archive_dir, f) end
  local secrets = { 'SECRET: the Void has four doors.', 'SECRET: the colon opens them all.' }

  local archive = {
    name = 'The Archive of Worlds',
    music = 'bgm_archive',
    par = 90,
    keys = { '`:!ls` run a command', '`:w name` write a copy', '`v` select, then `:w name`', '`:r name` read a file in', '`:r !ls` read a command in' },
    intro = {
      wizard('archive', 'The Archive of Worlds. Every book here is a real FILE - and Vim can read them, write them, even talk to the world outside.'),
      wizard('archive', '`:!` runs a command in the outside world: :!ls lists the files here. It all starts with the colon. Press it!', ':'),
      wizard('archive', '`:w name` writes a copy under a new name. And `v` selects text - then :w name saves ONLY the selection. Press v!', 'v'),
      wizard('archive', '`:r name` reads a whole file INTO your scroll. And :r !ls reads the outside world\'s answer in!'),
      stranger('archive', 'Read every file, knight. Some of them were written by... me.'),
    },
    outro = {
      hero('archive', '"The Void has four doors"... "The First Knight was here"... Who IS the First Knight?'),
      stranger('archive', 'The wizard knows. Go to his study. Read his diary. Then you will understand everything.'),
    },
    modifiable = true,
    buftype = '',
    file = function() return apath 'archive_notes.txt' end,
    lines = {
      '=== ARCHIVE NOTES ===',
      'These notes belong to the Archive.',
      '',
      secrets[1],
      secrets[2],
      '',
      '-- read other scrolls in below --',
    },
    setup = function(ctx)
      vim.fn.mkdir(archive_dir, 'p')
      for _, f in ipairs({ 'scroll.txt', 'secret.txt', 'archive_notes.txt' }) do
        os.remove(apath(f))
      end
      vim.fn.writefile({ 'X marks the spot: under the third oak.', 'Dig with your keyboard, never a mouse.' }, apath 'map.txt')
      vim.fn.writefile({ 'The First Knight was here.', 'He never found the door.' }, apath 'first_knight.txt')
      vim.cmd.tcd(vim.fn.fnameescape(archive_dir))
      ctx.match('VQRuneText', 'SECRET')
    end,
    poll = true,
    objectives = {
      {
        text = 'Peek at the outside world: `:!ls`',
        tip = 'Type `:!ls` and `Enter`. Vim runs ls and shows the files in this folder. Press `Enter` to come back.',
        check = function(ctx) return ctx.state().shell or ctx.ran '^:!' end,
      },
      {
        text = 'Write a copy of these notes: `:w scroll.txt`',
        tip = 'Type `:w scroll.txt` and `Enter`. A new file appears in the Archive.',
        check = function() return vim.uv.fs_stat(apath 'scroll.txt') ~= nil end,
      },
      {
        text = 'Select the 2 SECRET lines with `v`, write them to secret.txt',
        tip = 'Go to the first SECRET line, press `v`, then `j`. Press `:` - Vim adds \'<,\'> for you - type w secret.txt and `Enter`.',
        check = function()
          local ok, lines = pcall(vim.fn.readfile, apath 'secret.txt')
          return ok and eq(lines, secrets)
        end,
      },
      {
        text = 'Read the treasure map in: `:r map.txt`',
        tip = 'Press `G` to go to the last line. Type `:r map.txt` and `Enter` - the map appears below the cursor.',
        check = function(ctx) return find_line(ctx, 'X marks the spot: under the third oak.') ~= nil end,
      },
      {
        text = 'Read the outside world in: `:r !ls`',
        tip = 'Type `:r !ls` and `Enter`. The list of files becomes text in your scroll!',
        check = function(ctx) return find_line(ctx, 'secret.txt') ~= nil end,
      },
    },
  }

  -- Chapter 13: the Wizard's Study --------------------------------------------------------------

  local function help_open(ctx)
    for _, w in ipairs(api.nvim_tabpage_list_wins(ctx.state().tab)) do
      if vim.bo[api.nvim_win_get_buf(w)].buftype == 'help' then return true end
    end
    return false
  end

  local study = {
    name = "The Wizard's Study",
    music = 'bgm_study',
    par = 120,
    victory = true,
    keys = { '`:set ic` / `:set noic` case', '`:set hlsearch` `:set incsearch`', '`Tab` complete  `Ctrl-d` list', '`:help`  `Ctrl-w Ctrl-w` windows' },
    intro = {
      page('narrator', 'study', 'Escarion\'s study. Candles. Dust. A diary chained to the desk... and tonight, the chain is unlocked.', { fx = 'flicker' }),
      hero('study', 'I should not read it. But I have to know.'),
      page('stranger', 'study', 'Then bend Vim to your will. `:set` changes how it behaves. Press the colon!', { press = ':', fx = 'flicker' }),
      stranger('study', ':set ic makes searches ignore case. :set hlsearch lights up every match. :set incsearch searches as you type. Put no in front to turn one off.', 'flicker'),
      page('stranger', 'study', 'Typing long commands? `Tab` completes a word, `Ctrl-d` lists every choice. Hold Ctrl and press d!', { press = '<C-d>', fx = 'flicker' }),
      page('stranger', 'study', '`:help` opens Vim\'s own book of everything, and `Ctrl-w Ctrl-w` hops between windows. Press Ctrl-w twice!', { press = '<C-w><C-w>', fx = 'flicker' }),
      stranger('study', 'And your settings can live forever in a spellbook of your own - your config file. :echo $MYVIMRC shows where it is.'),
    },
    outro = function(save)
      local runes = 0
      for i = 1, 7 do
        if save.runes[tostring(i)] then runes = runes + 1 end
      end
      local pages = {
        page('narrator', 'study', 'The last page of the diary: "He asked me how to leave. I could not bear to lose another knight. So I hid the words of leaving."', { fx = 'flicker glitch' }),
        page('wizard', 'study', 'You read my diary. ...Then you know. Please, knight. Do not go looking for the Void.', { fx = 'flicker' }),
        hero('study', 'You trapped him, Escarion. Clickmore is defeated, Textoria is free... but someone is still lost. THE END?'),
      }
      if runes == 7 then
        pages[#pages + 1] = stranger('study', 'Seven runes, knight. E-X-I-T-V-I-M. The Void is open. Come and find me.')
      else
        pages[#pages + 1] = stranger('study', ('You found %d of 7 runes in the old lands. Find them all... and the Void will open.'):format(runes))
      end
      return pages
    end,
    modifiable = false,
    lines = {
      '~ The Diary of Escarion ~',
      'Day 1. A new knight arrived today.',
      'Day 9. He learns quickly. Too quickly.',
      'Day 40. He asked me how to LEAVE Vim.',
      'Day 41. I hid the words. The SECRET is safe.',
      'Day 90. He searches the Void now. Alone.',
      'Day 7300. Twenty years. I still hear him knocking.',
    },
    setup = function(ctx)
      local S = ctx.state()
      S.opts = { ignorecase = vim.o.ignorecase, smartcase = vim.o.smartcase, hlsearch = vim.o.hlsearch, incsearch = vim.o.incsearch }
      vim.o.ignorecase, vim.o.smartcase, vim.o.hlsearch, vim.o.incsearch = false, false, false, false
      local buf = S.buf
      api.nvim_buf_create_user_command(buf, 'VimQuestStay', function()
        ctx.sound 'error'
        ctx.say('Not here! :q in the diary would close it. Hop into the help window first (Ctrl-w Ctrl-w). To leave the chapter use :tabclose.', 'VQBad')
      end, { bang = true, nargs = '*' })
      api.nvim_buf_call(buf, function()
        for _, w in ipairs({ 'q', 'quit', 'wq', 'x' }) do
          vim.cmd(("cnoreabbrev <buffer> <expr> %s getcmdtype() ==# ':' && getcmdline() ==# '%s' ? 'VimQuestStay' : '%s'"):format(w, w, w))
        end
      end)
      ctx.match('VQRuneText', '\\cSECRET')
    end,
    teardown = function(S)
      for k, v in pairs(S.opts or {}) do
        vim.o[k] = v
      end
    end,
    tick = function(ctx)
      if math.random() < 0.006 then ctx.flicker(140, true) end
    end,
    poll = true,
    objectives = {
      {
        text = 'Search the diary for: secret',
        tip = 'Type `/secret` and press `Enter`. Watch the bottom of the screen...',
        start = function(ctx) ctx.set_cursor(1, 0) end,
        check = function(ctx)
          if not ctx.ran '^/secret$' then return false end
          ctx.state().sticky = true
          ctx.say('"Pattern not found"! The diary says SECRET in capitals - and right now, Vim searches care about case.', 'VQBad')
          return true
        end,
      },
      {
        text = 'Ignore case with `:set ic`, then search again',
        tip = 'Type `:set ic` and `Enter`. Then `/secret` and `Enter` again - now it finds SECRET!',
        check = function(ctx) return vim.o.ignorecase and cursor_on(ctx, 5, 'SECRET') end,
      },
      {
        text = 'Light up matches: `:set hlsearch` (peek with `Ctrl-d`)',
        tip = 'Type `:set hl` then hold Ctrl and press d to list every option starting with hl. Finish typing hlsearch and press `Enter`.',
        check = function(ctx) return vim.o.hlsearch and ctx.typed('<C-D>', 'c') end,
      },
      {
        text = 'Search as you type: `:set incsearch` (complete with `Tab`)',
        tip = 'Type `:set incs` then press `Tab` - Vim finishes the word for you! Then `Enter`.',
        check = function(ctx) return vim.o.incsearch and ctx.typed('<Tab>', 'c') end,
      },
      {
        text = 'Make case matter again: `:set noic`',
        tip = 'no in front turns an option OFF. Type `:set noic` and `Enter`.',
        check = function() return not vim.o.ignorecase end,
      },
      {
        text = 'Open the book of everything: `:help`',
        tip = 'Type `:help` and `Enter`. A help window opens above the diary.',
        check = help_open,
      },
      {
        text = 'Hop back to the diary: `Ctrl-w Ctrl-w`',
        tip = 'Hold Ctrl and press w twice. The cursor jumps to the other window.',
        check = function(ctx) return help_open(ctx) and api.nvim_get_current_win() == ctx.state().win and ctx.typed '<C-W>' end,
      },
      {
        text = 'Close the help book with `:q`',
        tip = 'Press `Ctrl-w Ctrl-w` to hop INTO the help window, then type `:q` and `Enter`. :q closes only the window you are in.',
        check = function(ctx) return not help_open(ctx) end,
      },
      {
        text = 'Find your own spellbook: `:echo $MYVIMRC`',
        tip = 'Type `:echo $MYVIMRC` and `Enter`. That file is YOUR config - settings like vim.o.ignorecase = true placed there last forever.',
        check = function(ctx) return ctx.ran 'echo%s+%$MYVIMRC' end,
      },
    },
  }

  return { mirrors, clock, forge, echo, archive, study }
end
