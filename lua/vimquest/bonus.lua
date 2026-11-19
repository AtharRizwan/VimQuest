-- Bonus chapters: real-world Neovim (files, the file tree, finders, windows) in a sandbox folder
local api = vim.api

local M = {}
M.dir = vim.fs.joinpath(vim.fn.stdpath 'data', 'vimquest', 'workshop')

local function path(f) return vim.fs.joinpath(M.dir, f) end
local function exists(f) return vim.uv.fs_stat(path(f)) ~= nil end

-- Fresh sandbox with the given files: { ['name'] = { lines } }
local function sandbox(files)
  if M.dir:match 'vimquest[/\\]workshop$' then vim.fn.delete(M.dir, 'rf') end
  vim.fn.mkdir(M.dir, 'p')
  for name, lines in pairs(files or {}) do
    vim.fn.mkdir(vim.fs.dirname(path(name)), 'p')
    vim.fn.writefile(lines, path(name))
  end
end

local function cur_name() return vim.fn.fnamemodify(api.nvim_buf_get_name(0), ':t') end

local function tab_wins(ctx)
  return vim.tbl_filter(function(w) return api.nvim_win_get_config(w).relative == '' end, api.nvim_tabpage_list_wins(ctx.state().tab))
end

local function shows(ctx, pred)
  for _, w in ipairs(api.nvim_tabpage_list_wins(ctx.state().tab)) do
    if pred(api.nvim_win_get_buf(w)) then return true end
  end
  return false
end

local function tree_open(ctx) return shows(ctx, function(b) return vim.bo[b].filetype == 'neo-tree' end) end
local function term_open(ctx) return shows(ctx, function(b) return vim.bo[b].buftype == 'terminal' end) end

-- Buffers opened inside the sandbox are wiped when the chapter ends
local function teardown()
  vim.schedule(function()
    for _, b in ipairs(api.nvim_list_bufs()) do
      local name = api.nvim_buf_get_name(b)
      local sandboxed = name:sub(1, #M.dir) == M.dir or name:find('vimquest/workshop', 1, true) ~= nil
      if sandboxed or (name == '' and vim.bo[b].buftype == '' and not vim.bo[b].modified and api.nvim_buf_line_count(b) <= 1) then
        if #vim.fn.win_findbuf(b) == 0 then pcall(api.nvim_buf_delete, b, { force = true }) end
      end
    end
  end)
end

return function(H)
  local page, wizard, hero, stranger = H.page, H.wizard, H.hero, H.stranger

  local function common(ch)
    ch.bonus = true
    ch.workspace = true
    ch.poll = true
    ch.modifiable = false
    ch.teardown = teardown
    return ch
  end

  local files = common {
    name = "Bonus I · The Scribe's Workshop",
    music = 'bgm_scribe',
    par = 70,
    keys = { '`:e name` open or CREATE a file', '`:w` save   `:w name` save as', '`:enew` blank page   `:pwd` where am I' },
    intro = {
      wizard('study', 'Welcome to the Scribe\'s Workshop, knight. Out here in the real world you will make your OWN files.'),
      wizard('study', 'The secret nobody tells beginners: Vim never asks for a name. YOU give the name, in a command. It all starts with the colon. Press it!', ':'),
      wizard('study', '`:e potion.txt` opens a file called potion.txt. If it does not exist yet, Vim creates it. Then `:w` saves it to disk.'),
      wizard('study', 'Already typing on a blank page with no name? `:w recipe.txt` saves it AND gives it that name.'),
      hero('study', 'So :e to open or create, :w to save. That is all it takes?'),
      wizard('study', 'That is all. Everything here happens in a safe practice folder - break whatever you like.'),
    },
    outro = {
      hero('study', 'I made two files all by myself! potion.txt and recipe.txt!'),
      wizard('study', 'Remember: :e name to open or create, :w to save, :w name to save as. You will use these every single day.'),
    },
    lines = {
      '~ THE SCRIBE\'S WORKSHOP ~',
      '',
      'This page is your quest scroll.',
      'Follow the quest log on the right.',
      '',
      'Creating a file in Vim:',
      ' :e potion.txt  open (or create)',
      ' :w             save',
      ' :w name.txt    save as a new name',
    },
    setup = function() sandbox { ['README.txt'] = { 'This is your practice folder.' } } end,
    objectives = {
      {
        text = 'Ask where you are: `:pwd`',
        tip = 'Type `:pwd` and press `Enter`. It prints the folder you are working in - new files go there.',
        check = function(ctx) return ctx.ran '^:pwd' end,
      },
      {
        text = 'Create a new file: `:e potion.txt`',
        tip = 'Type `:e potion.txt` and press `Enter`. You now have an empty file called potion.txt open.',
        check = function() return cur_name() == 'potion.txt' end,
      },
      {
        text = 'Write a line in it, then `Esc`',
        tip = 'Press `i`, type anything you like (a potion recipe?), then press `Esc`.',
        check = function(ctx) return cur_name() == 'potion.txt' and ctx.mode() == 'n' and vim.trim(table.concat(api.nvim_buf_get_lines(0, 0, -1, false))) ~= '' end,
      },
      {
        text = 'Save it to disk: `:w`',
        tip = 'Type `:w` and press `Enter`. The bottom line shows "potion.txt written".',
        check = function()
          local ok, lines = pcall(vim.fn.readfile, path 'potion.txt')
          return ok and vim.trim(table.concat(lines)) ~= ''
        end,
      },
      {
        text = 'Open a blank page with no name: `:enew`',
        tip = 'Type `:enew` and `Enter`. A fresh page appears - it has no name yet.',
        check = function() return api.nvim_buf_get_name(0) == '' and vim.bo.buftype == '' end,
      },
      {
        text = 'Name it while saving: `:w recipe.txt`',
        tip = 'Type something first if you like (`i` ... `Esc`), then `:w recipe.txt` and `Enter`. The page now has a name!',
        check = function() return exists 'recipe.txt' end,
      },
      {
        text = 'Go back to your potion: `:e potion.txt`',
        tip = 'Type `:e potion.txt` and `Enter`. :e also opens files that already exist.',
        check = function() return cur_name() == 'potion.txt' end,
      },
    },
  }

  local tree = common {
    name = 'Bonus II · The File Tree',
    music = 'bgm_tree',
    par = 90,
    keys = { '`\\` open / close the tree', '`j` `k` move  `Enter` open', '`a` add file (end with / = folder)', '`r` rename   `d` delete' },
    intro = {
      wizard('tree', 'Behold the File Tree! Every branch is a folder, every fruit a file. Press backslash to open it - the key above Enter.', '\\'),
      wizard('tree', 'Inside the tree, `j` and `k` move up and down, and `Enter` opens a file or a folder. Press j!', 'j'),
      wizard('tree', '`a` ADDS a new file: type its name and press Enter. End the name with / and you get a folder instead. Press a!', 'a'),
      wizard('tree', '`r` RENAMES the file under the cursor and `d` DELETES it - the tree asks first, answer y. Press r!', 'r'),
      hero('tree', 'So I never need to remember a command to make a file - the tree asks me for a name!'),
    },
    outro = {
      wizard('tree', 'You planted files, grew folders and pruned the junk. The tree is your map of any project.'),
      hero('tree', 'Backslash to open, a to add. I am never typing a file name blind again.'),
    },
    lines = {
      '~ THE FILE TREE ~',
      '',
      'Press \\ (backslash) to open the tree.',
      'Follow the quest log on the right.',
      '',
      'Inside the tree:',
      ' j / k    move up and down',
      ' Enter    open a file or folder',
      ' a        add (name/ = folder)',
      ' r / d    rename / delete',
      ' q        close the tree',
    },
    setup = function()
      sandbox {
        ['map.txt'] = { 'A map of the File Tree.' },
        ['old_scroll.txt'] = { 'This scroll wants a new name.' },
        ['junk.txt'] = { 'Delete me, please.' },
        ['spells/fireball.txt'] = { 'FIREBALL: point and say :w' },
      }
    end,
    objectives = {
      {
        text = 'Open the tree: `\\`',
        tip = 'Press `\\` (backslash, the key above Enter). The tree opens on the left.',
        check = tree_open,
      },
      {
        text = 'Open map.txt from the tree',
        tip = 'Move onto map.txt with `j` and `k`, then press `Enter`.',
        check = function() return cur_name() == 'map.txt' end,
      },
      {
        text = 'Add a new file: spellbook.txt',
        tip = 'Press `\\` to jump into the tree, press `a`, type spellbook.txt and press `Enter`.',
        check = function() return exists 'spellbook.txt' end,
      },
      {
        text = 'Add a folder: potions/',
        tip = 'In the tree press `a`, type potions/ - the slash at the end makes it a FOLDER - and `Enter`.',
        check = function() return vim.fn.isdirectory(path 'potions') == 1 end,
      },
      {
        text = 'Rename old_scroll.txt to new_scroll.txt',
        tip = 'Move onto old_scroll.txt and press `r`. The box shows the old name: press `Ctrl-u` to erase it, type new_scroll.txt, then `Enter`.',
        check = function() return exists 'new_scroll.txt' and not exists 'old_scroll.txt' end,
      },
      {
        text = 'Delete junk.txt',
        tip = 'Move onto junk.txt and press `d`. The tree asks y/n: type y, then press `Enter`.',
        check = function() return not exists 'junk.txt' end,
      },
      {
        text = 'Open spells/fireball.txt',
        tip = 'Move onto the spells folder and press `Enter` to open it, then onto fireball.txt and `Enter` again.',
        check = function() return cur_name() == 'fireball.txt' end,
      },
      {
        text = 'Close the tree: `\\` or `q`',
        tip = 'Press `\\` to jump into the tree, then `q` to close it - or press `\\` again while you are in it.',
        check = function(ctx) return not tree_open(ctx) end,
      },
    },
  }

  local finders = common {
    name = 'Bonus III · Finders & Open Files',
    music = 'bgm_finders',
    par = 80,
    keys = { '`Space sf` find a file by name', '`Space sg` search inside files', '`Space Space` open files list', '`Shift-h` `Shift-l` previous / next', '`Space bd` close a file' },
    intro = {
      wizard('library', 'Real projects have hundreds of files, hidden in folders inside folders. You will never hunt by hand again.'),
      wizard('library', 'Space is your LEADER key. `Space sf` means Search Files: press Space, then s, then f. Try it!', '<Space>sf'),
      wizard('library', '`Space sg` searches INSIDE every file for a word. Press Space, s, g!', '<Space>sg'),
      wizard('library', 'Every file you open stays open as a BUFFER - see the tabs at the top? `Shift-l` and `Shift-h` flip between them. Press Shift + l!', 'L'),
      wizard('library', '`Space Space` lists your open files to jump between, and `Space bd` closes one. In a finder: type to filter, Enter to open, Esc to cancel.'),
    },
    outro = {
      hero('library', 'Space sf for names, Space sg for words inside. I could find anything in seconds.'),
      wizard('library', 'And Shift-h and Shift-l to flip between open files. This is how real knights work all day.'),
    },
    lines = {
      '~ FINDERS & OPEN FILES ~',
      '',
      'Follow the quest log on the right.',
      '',
      ' Space sf     find a file by name',
      ' Space sg     find a word inside',
      ' Space Space  list open files',
      ' Shift-h / l  previous / next file',
      ' Space bd     close this file',
      '',
      'Finders: type, Enter opens, Esc quits',
    },
    setup = function()
      local files = { ['deep/down/below/treasure.txt'] = { 'You found the treasure!' }, ['cake.txt'] = { 'A slice of cake.' } }
      for i = 1, 9 do
        files[('notes_%d.txt'):format(i)] = { ('Note number %d. Nothing special here.'):format(i) }
      end
      files['notes_7.txt'] = { 'Note number 7.', 'Here sleeps the DRAGON.' }
      sandbox(files)
    end,
    objectives = {
      {
        text = 'Find treasure.txt by name: `Space sf`',
        tip = 'Press `Space` `s` `f`, type treasure, then `Enter`. It is buried three folders deep!',
        check = function() return cur_name() == 'treasure.txt' end,
      },
      {
        text = 'Which file hides the DRAGON? `Space sg`',
        tip = 'Press `Space` `s` `g`, type DRAGON, then `Enter` to open the file it is in.',
        check = function() return cur_name() == 'notes_7.txt' end,
      },
      {
        text = 'Open cake.txt (any way you like)',
        tip = 'Use `Space sf` and type cake - or simply `:e cake.txt`.',
        check = function() return cur_name() == 'cake.txt' end,
      },
      {
        text = 'Flip between open files with `Shift-h` / `Shift-l`',
        tip = 'Hold Shift and press h for the previous open file, l for the next. Watch the tabs at the top!',
        check = function(ctx) return (ctx.typed 'H' or ctx.typed 'L') and cur_name() ~= 'cake.txt' and cur_name():match '%.txt$' ~= nil end,
      },
      {
        text = 'Jump to treasure.txt from the list: `Space Space`',
        tip = 'Press `Space` twice. A list of open files appears - type treas and press `Enter`.',
        check = function(ctx) return cur_name() == 'treasure.txt' and ctx.typed '<Space>' end,
      },
      {
        text = 'Close treasure.txt: `Space bd`',
        tip = 'While treasure.txt is showing, press `Space` `b` `d`. Its tab disappears from the top.',
        check = function()
          for _, b in ipairs(api.nvim_list_bufs()) do
            if vim.bo[b].buflisted and vim.fn.fnamemodify(api.nvim_buf_get_name(b), ':t') == 'treasure.txt' then return false end
          end
          return true
        end,
      },
    },
  }

  local windows = common {
    name = 'Bonus IV · Windows & the Terminal',
    music = 'bgm_windows',
    par = 80,
    keys = { '`:vsplit name` side by side', '`:split name` top and bottom', '`Ctrl-h/j/k/l` move between windows', '`:q` close a window', '`Ctrl-\\` terminal   `:wa` save all' },
    intro = {
      wizard('mirrors', 'One screen, many windows. Look at two files side by side, or keep a terminal at hand.'),
      wizard('mirrors', '`:vsplit name` opens a file in a new window beside this one, and `:split name` puts it above. Begin with the colon!', ':'),
      wizard('mirrors', 'To move between windows, hold Ctrl and press the direction: Ctrl-h left, Ctrl-l right, Ctrl-j down, Ctrl-k up. Try Ctrl-l!', '<C-l>'),
      wizard('mirrors', '`:q` closes just the window you are in. And `Ctrl-\\` pops open a terminal - press it again to hide it.'),
      stranger('mirrors', 'A word of warning, knight: :qa closes EVERY window... and Vim itself. Use it only when your work is done.'),
    },
    outro = {
      hero('mirrors', 'Two files side by side, a terminal one key away, and everything saved with :wa. I feel like a real programmer!'),
      wizard('mirrors', 'You ARE one now. Go build something wonderful, Vim Knight.'),
    },
    lines = {
      '~ WINDOWS & THE TERMINAL ~',
      '',
      'Follow the quest log on the right.',
      '',
      ' :vsplit name   file beside this one',
      ' :split name    file above this one',
      ' Ctrl-h/j/k/l   move between windows',
      ' :q             close this window',
      ' Ctrl-\\         show / hide terminal',
      ' :wa            save every open file',
    },
    setup = function()
      sandbox {
        ['left.txt'] = { 'I am the left page.' },
        ['right.txt'] = { 'I am the right page.' },
      }
    end,
    objectives = {
      {
        text = 'Open right.txt beside you: `:vsplit right.txt`',
        tip = 'Type `:vsplit right.txt` and `Enter`. The screen splits into two windows side by side.',
        check = function(ctx)
          return #tab_wins(ctx) >= 2 and shows(ctx, function(b) return vim.fn.fnamemodify(api.nvim_buf_get_name(b), ':t') == 'right.txt' end)
        end,
      },
      {
        text = 'Hop to the other window: `Ctrl-h` / `Ctrl-l`',
        tip = 'Hold Ctrl and press h to go left or l to go right. (`Ctrl-w h` and `Ctrl-w l` do the same.)',
        start = function(ctx) ctx.state().hop_from = api.nvim_get_current_win() end,
        check = function(ctx)
          local hopped = ctx.typed '<C-H>' or ctx.typed '<C-L>' or ctx.typed '<C-W>'
          return hopped and api.nvim_get_current_win() ~= ctx.state().hop_from
        end,
      },
      {
        text = 'Open left.txt above you: `:split left.txt`',
        tip = 'Type `:split left.txt` and `Enter`. Now you have three windows!',
        check = function(ctx) return #tab_wins(ctx) >= 3 end,
      },
      {
        text = 'Close the window you are in: `:q`',
        tip = 'Type `:q` and `Enter`. Only this window closes - the file and the others stay.',
        check = function(ctx) return #tab_wins(ctx) == 2 end,
      },
      {
        text = 'Open the terminal: `Ctrl-\\`',
        tip = 'Hold Ctrl and press \\ (backslash). Type ls and `Enter` to list the files - real commands work here!',
        check = term_open,
      },
      {
        text = 'Hide the terminal again: `Ctrl-\\`',
        tip = 'Press `Ctrl-\\` once more. The terminal hides but keeps running for next time.',
        check = function(ctx) return not term_open(ctx) end,
      },
      {
        text = 'Change a file, then save everything: `:wa`',
        tip = 'Hop into right.txt with `Ctrl-l`, press `A`, type a word, then `Esc`. Then `:wa` (write all) and `Enter`.',
        check = function(ctx)
          if not ctx.ran '^:wa' then return false end
          for _, b in ipairs(api.nvim_list_bufs()) do
            if vim.bo[b].modified and api.nvim_buf_get_name(b):sub(1, #M.dir) == M.dir then return false end
          end
          for _, f in ipairs({ 'left.txt', 'right.txt' }) do
            local ok, lines = pcall(vim.fn.readfile, path(f))
            if ok and #table.concat(lines) > #('I am the left page.') + 1 then return true end
          end
          return false
        end,
      },
    },
  }

  for _, ch in ipairs({ files, tree, finders, windows }) do
    ch.cwd = M.dir
  end
  return { files, tree, finders, windows }
end
