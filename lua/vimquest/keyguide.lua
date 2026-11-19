-- How to type each key, written for people who have never used Vim
local M = {}

local guide = {
  h = 'right index finger, left of j · LEFT',
  j = 'right index finger (bump key) · DOWN',
  k = 'right middle finger · UP',
  l = 'right ring finger · RIGHT',
  w = 'w = word · next word',
  b = 'b = back · previous word',
  e = 'e = end · end of the word',
  ['0'] = 'the zero key · start of line',
  ['$'] = 'Shift + 4 · end of line',
  x = 'deletes the letter under the cursor',
  d = 'd = delete · waits for what to delete',
  dd = 'press d twice · deletes the line',
  ['2dd'] = 'type 2, then d d · deletes 2 lines',
  u = 'u = undo · takes back your last change',
  ['Ctrl-r'] = 'hold Ctrl, press r · redo',
  i = 'i = insert · type BEFORE the cursor',
  a = 'a = append · type AFTER the cursor',
  A = 'Shift + a · type at END of line',
  o = 'o = open · new line below',
  Esc = 'top-left key · back to Normal mode',
  ['<Esc>'] = 'top-left key · back to Normal mode',
  ['*'] = 'Shift + 8 · search word under cursor',
  n = 'n = next · next search match',
  N = 'Shift + n · previous match',
  ['.'] = 'period key · repeat last change',
  ciw = 'press c, i, w · change this word',
  dw = 'press d, w · delete a word',
  cw = 'press c, w · change rest of word',
  ['/'] = 'key left of right Shift · search',
  ['/KEY'] = 'press / then Shift+k Shift+e Shift+y',
  Enter = 'the big Return key · run it',
  ['<CR>'] = 'the big Return key · run it',
  G = 'Shift + g · LAST line',
  gg = 'press g twice · FIRST line',
  [':'] = 'Shift + ; · opens the command line',
  V = 'Shift + v · select whole lines',
  [':w'] = 'Shift+; w Enter · save',
  [':q'] = 'Shift+; q Enter · quit (closes a window)',
  [':q!'] = 'Shift+; q Shift+1 Enter · quit, no save',
  [':wq'] = 'Shift+; w q Enter · save and quit',
  ZZ = 'Shift + z, twice · save and quit',
  [':%s/click/press/g'] = 'Shift+; then type the rest, Enter',
  yy = 'press y twice · copy (yank) the line',
  yw = 'press y, w · copy (yank) a word',
  p = 'p = put · paste after the cursor',
  r = 'r then a letter · replace ONE letter',
  ro = 'press r, then o · turn a letter into o',
  R = 'Shift + r · type OVER letters (Replace mode)',
  ['R Esc'] = 'Shift + r, then Esc · enter and leave Replace mode',
  O = 'Shift + o · new line ABOVE',
  U = 'Shift + u · undo ALL changes on the line',
  ['Ctrl-g'] = 'hold Ctrl, press g · where am I?',
  ['?'] = 'Shift + / · search UPWARD',
  ['?GEAR'] = 'Shift+/ then G E A R, Enter · search up',
  ['%'] = 'Shift + 5 · jump to the matching bracket',
  ['Ctrl-o'] = 'hold Ctrl, press o · jump BACK',
  ['Ctrl-i'] = 'hold Ctrl, press i (same as Tab) · jump FORWARD',
  Tab = 'the Tab key · complete a word / jump forward',
  ['d$'] = 'press d, then Shift+4 · delete to end of line',
  D = 'Shift + d · same as d$',
  d2w = 'press d, 2, w · delete two words',
  ce = 'press c, e · change to end of word',
  ['c$'] = 'press c, then Shift+4 · change to end of line',
  ['Ctrl-r'] = 'hold Ctrl, press r · redo what you undid',
  ['Ctrl-w'] = 'hold Ctrl, press w · window command',
  ['Ctrl-w Ctrl-w'] = 'hold Ctrl, press w twice · hop to next window',
  ['Ctrl-d'] = 'hold Ctrl, press d · list every choice',
  v = 'v = visual · select text',
  [':!ls'] = 'Shift+; ! l s Enter · run ls outside Vim',
  [':w scroll.txt'] = 'Shift+; w, space, the name, Enter · save a copy',
  [":'<,'>w secret.txt"] = 'press : while text is selected, then w secret.txt',
  [':r map.txt'] = 'Shift+; r, space, map.txt, Enter · read a file in',
  [':r !ls'] = 'Shift+; r ! l s Enter · read a command in',
  [':s/squeak/speak'] = 'Shift+; then s/squeak/speak, Enter · first match',
  [':s/squeak/speak/g'] = 'add /g · every match on this line',
  [':5,7s/mouse/keyboard/g'] = 'lines 5 to 7 only',
  [':%s/cheese/bread/gc'] = 'c = confirm · press y or n each time',
  ['/secret'] = 'press / then type secret, Enter',
  [':set ic'] = 'Shift+; set ic Enter · ignore case',
  [':set hlsearch'] = 'Shift+; set hlsearch Enter · highlight matches',
  [':set incsearch'] = 'Shift+; set incsearch Enter · search as you type',
  [':set noic'] = 'Shift+; set noic Enter · case matters again',
  [':help'] = 'Shift+; help Enter · the manual',
  [':echo $MYVIMRC'] = 'Shift+; echo $MYVIMRC Enter · your config file',
  ['\\'] = 'backslash, the key above Enter · file tree',
  a = 'a = append · or in the tree: add a file',
  ['Space sf'] = 'Space, then s, then f · search files',
  ['Space sg'] = 'Space, then s, then g · search inside files',
  ['Space Space'] = 'Space twice · list open files',
  ['Space bd'] = 'Space, then b, then d · close this file',
  ['Shift-h'] = 'hold Shift, press h · previous open file',
  ['Shift-l'] = 'hold Shift, press l · next open file',
  ['Ctrl-h'] = 'hold Ctrl, press h · window on the left',
  ['Ctrl-l'] = 'hold Ctrl, press l · window on the right',
  ['Ctrl-\\'] = 'hold Ctrl, press \\ · show / hide terminal',
  ['Ctrl-w h'] = 'Ctrl-w, then h · window on the left',
  ['Ctrl-w l'] = 'Ctrl-w, then l · window on the right',
  q = 'q = quit · closes the tree',
  ['Ctrl-u'] = 'hold Ctrl, press u · erase what you typed',
}

-- Turns key codes like <C-o> into friendly names like Ctrl-o
function M.pretty(key)
  local names = { ['<Esc>'] = 'Esc', ['<CR>'] = 'Enter', ['<Tab>'] = 'Tab', ['<Space>'] = 'Space', ['<BS>'] = 'Backspace' }
  key = key:gsub('<[^>]+>', function(k)
    if names[k] then return ' ' .. names[k] .. ' ' end
    local c = k:match '^<[Cc]%-(.)>$'
    return c and (' Ctrl-' .. c:lower() .. ' ') or k
  end)
  return vim.trim((key:gsub('%s+', ' ')))
end

-- Describes a key; counts like 5j or 42G become "type 5, then ..."
function M.describe(key)
  if guide[key] then return guide[key] end
  if guide[M.pretty(key)] then return guide[M.pretty(key)] end
  if key:match '^:%a' then return ('Shift + ; then type %s, then Enter'):format(key:sub(2)) end
  local num, rest = key:match '^(%d+)(.+)$'
  if num then
    if rest == 'G' then return ('type %s, then Shift + g · go to line %s'):format(table.concat(vim.split(num, ''), ', '), num) end
    local inner = guide[rest] and guide[rest]:gsub('^.-· ', '') or rest
    return ('type %s, then %s · %s x%d'):format(table.concat(vim.split(num, ''), ', '), rest, inner, tonumber(num))
  end
end

-- Builds beginner lines for every `key` mentioned in a text
function M.explain(text)
  local out, seen = {}, {}
  for key in text:gmatch '`([^`]+)`' do
    local d = M.describe(key)
    if d and not seen[key] then
      seen[key] = true
      out[#out + 1] = '`' .. key .. '` ' .. d
    end
  end
  return out
end

return M
