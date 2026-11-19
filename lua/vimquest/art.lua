-- Sprites and scene backdrops for VimQuest
local P = require 'vimquest.pixel'
local M = {}

local C = {
  ink = '#1a1c2c',
  plum = '#5d275d',
  red = '#b13e53',
  orange = '#ef7d57',
  gold = '#ffcd75',
  lime = '#a7f070',
  green = '#38b764',
  teal = '#257179',
  navy = '#29366f',
  blue = '#3b5dc9',
  sky = '#41a6f6',
  cyan = '#73eff7',
  white = '#f4f4f4',
  silver = '#94b0c2',
  grey = '#566c86',
  slate = '#333c57',
}
M.C = C

M.sprites = {
  hero = {
    rows = {
      '......rr......',
      '.....rr.......',
      '....kkkkkk....',
      '...kSSSSSSk.w.',
      '...kSkcckSk.w.',
      '...kSSSSSSk.w.',
      '....kkkkkk..w.',
      '...kbbbbbbkkyk',
      '..kbbbyybbbkf.',
      '..kbbyyyybbk..',
      '..kbbbyybbbk..',
      '...kbbbbbbk...',
      '...kkk..kkk...',
      '..kkkk..kkkk..',
    },
    pal = { r = C.red, k = C.ink, S = C.silver, c = C.cyan, b = C.blue, y = C.gold, w = C.white, f = C.grey },
  },
  wizard = {
    rows = {
      '......y.....co.',
      '.....ppp...cOOc',
      '....ppypp...co.',
      '...ppppppp...t.',
      '..kkkkkkkkk..t.',
      '....fkfkf....t.',
      '....fffff...ft.',
      '...wwwwwww.pft.',
      '..pwwwwwwwpp.t.',
      '.ppwwwwwwwp..t.',
      '.pppwwwwwpp..t.',
      '.ppppwwwppp..t.',
      '.pppppwpppp..t.',
      '.ppppppppppp.t.',
      '..ppppppppp..t.',
      '..kkk...kkk..t.',
    },
    pal = { y = C.gold, p = '#8f4bc4', k = C.ink, f = '#f2c6a0', w = C.white, t = '#8b5a2b', c = C.sky, o = C.cyan, O = C.white },
  },
  king = {
    rows = {
      '.ggg...y.y.y...ggg.',
      'gpppg..yyyyy..gpppg',
      'gpppg..yryry..gpppg',
      'gpppgggggggggggpppg',
      '.ggggggggggggggggg.',
      '..gggRRgggggRRggg..',
      '..gggkRgggggkRggg..',
      'W.ggggggggggggggg.W',
      '.WWgggggPPPgggggWW.',
      'W..ggggggPggggggg.W',
      '....gggkwkwkggg....',
      '...mmggggggggggmm..',
      '..mmmmggyyyggmmmm..',
      '.mmmmmmggyggmmmmmm.',
      '.mmmmmmggggggmmmmm.',
      '..mmmm.kk..kk.mmm..',
    },
    pal = { g = '#9a9ab0', p = '#f4a0b8', y = C.gold, r = C.red, R = '#ff004d', k = C.ink, W = C.white, P = '#ff77a8', w = C.white, m = '#7e2553' },
  },
  frog = {
    rows = { 'ww...ww', 'wkgggkw', 'ggggggg', 'gGGGGGg', 'g.g.g.g' },
    pal = { w = C.white, k = C.ink, g = C.green, G = C.teal },
  },
  bug = {
    rows = { 'k...k', '.rrr.', 'rrkrr', '.rrr.', 'k...k' },
    pal = { k = C.ink, r = '#ff004d' },
  },
  gem = {
    rows = { '.ccc.', 'cCwCc', 'cCCCc', '.cCc.', '..c..' },
    pal = { c = C.sky, C = C.cyan, w = C.white },
  },
  scroll = {
    rows = { '.bbbbbbbb.', 'bppppppppb', 'bpkkkpkkpb', 'bppppppppb', 'bpkkpkkkpb', '.bbbbbbbb.' },
    pal = { b = '#c8a26b', p = '#f4e4c1', k = C.plum },
  },
  key = {
    rows = { '.yyy.....', 'yy.yyyyyy', '.yyy..y.y' },
    pal = { y = C.gold },
  },
  stranger = {
    rows = {
      '.....HHHH.....',
      '....HhhhhH....',
      '...Hhhhhhhh...',
      '..Hhhkkkkhhh..',
      '..Hhkekkekhh..',
      '..Hhkkkkkkhh..',
      '..Hhhkkkkhhh..',
      '.HhhhhhhhhhhH.',
      '.Hhhhhhhhhhhhl',
      'Hhhhhhhhhhhlyl',
      'Hhhhhhhhhhhhl.',
      'Hhhhhhhhhhhhh.',
      '.Hhhhhhhhhhhh.',
      '.Hhhhhhhhhhhh.',
      '..hhhhhhhhhh..',
      '..kkk....kkk..',
    },
    pal = { H = '#3d2e57', h = '#2a1f3d', k = '#0d0a14', e = C.cyan, l = '#8b5a2b', y = C.gold },
  },
}

local R = P.rng

local function stars(c, f, ymax, seed)
  local r = R(seed or 7)
  for i = 1, 28 do
    local x, y = r(c.w), r(ymax)
    local tw = (i + f) % 7
    c:set(x, y, tw == 0 and C.white or (tw < 3 and C.silver or C.grey))
  end
end

local function hills(c, base, color, seed, maxh)
  local r = R(seed)
  local h = 2
  for x = 0, c.w - 1 do
    if x % 3 == 0 then h = math.max(1, math.min(maxh or 7, h + r(3) - 1)) end
    c:rect(x, base - h, 1, h, color)
  end
end

local function ground(c, y, top, fill)
  c:rect(0, y, c.w, c.h - y, fill)
  c:rect(0, y, c.w, 1, top)
end

local function moon(c, x, y)
  c:circle(x, y, 3, '#fff3c4')
  c:set(x - 1, y - 1, C.silver)
  c:set(x + 1, y + 1, C.silver)
end

local function castle(c, x, base, color, f)
  c:rect(x, base - 8, 12, 8, color)
  c:rect(x - 2, base - 12, 4, 12, color)
  c:rect(x + 10, base - 12, 4, 12, color)
  for i = 0, 2 do
    c:set(x - 2 + i * 2, base - 13, color)
    c:set(x + 10 + i * 2, base - 13, color)
  end
  c:rect(x + 4, base - 4, 4, 4, C.ink)
  c:set(x, base - 9, f % 4 == 0 and C.orange or C.gold)
  c:set(x + 12, base - 10, f % 5 == 0 and C.orange or C.gold)
end

M.scenes = {}

function M.scenes.night(c, f)
  c:gradient(0, 16, '#0b0b23', '#3b2a6b')
  stars(c, f, 12, 3)
  moon(c, 52, 4)
  hills(c, 17, C.navy, 5)
  castle(c, 26, 17, C.slate, f)
  ground(c, 17, C.lime, C.green)
end

function M.scenes.cave(c, f)
  c:fill('#1b1420')
  local r = R(11)
  for x = 0, c.w - 1 do
    local h = 1 + r(2) + (x % 7 == 3 and 3 + r(3) or 0)
    c:rect(x, 0, 1, h, '#3e2c41')
  end
  local g = R(4)
  for i = 1, 14 do
    local x, y = g(c.w), 4 + g(12)
    c:set(x, y, (i + f) % 4 == 0 and C.white or C.cyan)
  end
  c:sprite(30, 11, M.sprites.gem.rows, M.sprites.gem.pal)
  ground(c, 17, '#6b5444', '#4a3a2e')
end

function M.scenes.river(c, f)
  c:gradient(0, 11, '#41a6f6', '#bfeaff')
  hills(c, 12, '#5aa86a', 9, 4)
  c:rect(0, 12, c.w, 8, C.blue)
  for x = 0, c.w - 1, 5 do
    c:set((x + f) % c.w, 13 + math.floor(x / 5) % 6, C.sky)
  end
  for _, sx in ipairs({ 4, 24, 38, 52 }) do
    c:rect(sx, 17, 9, 2, C.silver)
    c:rect(sx + 1, 16, 7, 1, C.silver)
  end
  c:sprite(39, 11 + (f % 6 == 0 and -1 or 0), M.sprites.frog.rows, M.sprites.frog.pal)
end

function M.scenes.meadow(c, f)
  c:gradient(0, 13, '#41a6f6', '#d6f4ff')
  c:circle(56, 3, 2, C.gold)
  hills(c, 14, '#5aa86a', 2, 4)
  ground(c, 14, C.lime, C.green)
  for i = 1, 4 do
    local dir = i % 2 == 0 and 1 or -1
    c:sprite((i * 15 + f * dir) % 64, 13 + (i % 3) * 2, M.sprites.bug.rows, M.sprites.bug.pal)
  end
  c:sprite(40, 3, M.sprites.scroll.rows, M.sprites.scroll.pal)
end

function M.scenes.canyon(c, f)
  c:gradient(0, 14, '#ef7d57', '#5d275d')
  c:circle(32, 13, 4, C.gold)
  c:rect(0, 11, 22, 9, '#8b5a2b')
  c:rect(42, 11, 22, 9, '#8b5a2b')
  c:rect(0, 11, 22, 1, C.green)
  c:rect(42, 11, 22, 1, C.green)
  for x = 22, 41 do
    if x ~= 28 and x ~= 29 and x ~= 34 then c:set(x, 11, '#c8a26b') end
    if x % 3 == 0 then c:set(x, 10, C.silver) end
  end
  if f % 2 == 0 then c:set(29, 13 + f % 6, '#c8a26b') end
end

function M.scenes.tower(c, f)
  c:fill('#2b1d3a')
  for y = 0, 19, 3 do
    c:rect(0, y, c.w, 1, '#21162e')
    for x = (y % 6 == 0) and 0 or 3, c.w - 1, 6 do
      c:set(x, y + 1, '#21162e')
      c:set(x, y + 2, '#21162e')
    end
  end
  c:rect(26, 2, 12, 9, '#0b0b23')
  c:circle(31, 6, 2, '#fff3c4')
  c:sprite(28, 12 + (f % 4 < 2 and 0 or 1), M.sprites.scroll.rows, M.sprites.scroll.pal)
  for i = 0, 3 do
    c:set(26 + (f + i * 4) % 14, 12 - i, (f + i) % 2 == 0 and C.cyan or C.gold)
  end
  ground(c, 17, C.slate, '#1a1424')
end

function M.scenes.library(c, f)
  c:fill('#3a2418')
  local r = R(21)
  local books = { C.red, C.blue, C.green, C.gold, C.plum, C.teal, C.orange }
  for _, sy in ipairs({ 1, 7, 13 }) do
    local x = 0
    while x < c.w do
      local w, h = 1 + r(2), 4 + r(2)
      c:rect(x, sy + 5 - h, w, h, books[r(#books) + 1])
      x = x + w + (r(5) == 0 and 1 or 0)
    end
    c:rect(0, sy + 5, c.w, 1, '#6b4426')
  end
  c:sprite(30, 2, M.sprites.key.rows, M.sprites.key.pal)
  ground(c, 19, '#6b4426', '#6b4426')
  c:rect(56, 15, 2, 3, C.white)
  c:set(56 + f % 2, 14, f % 3 == 0 and C.orange or C.gold)
end

function M.scenes.throne(c, f)
  c:gradient(0, 17, '#1f0a17', '#5d1a2a')
  for _, px in ipairs({ 2, 58 }) do
    c:rect(px, 0, 4, 17, '#3a1424')
    c:set(px + 1, 6, f % 2 == 0 and C.orange or C.gold)
    c:set(px + 2, 5, f % 3 == 0 and C.gold or C.red)
  end
  c:rect(40, 0, 23, 17, '#4a1a2e')
  c:rect(44, 2, 15, 15, C.gold)
  c:rect(46, 4, 11, 13, '#7e2553')
  ground(c, 17, '#9e2a3a', '#6b1a28')
  c:rect(12, 17, 40, 3, '#b13e53')
end

function M.scenes.victory(c, f)
  c:gradient(0, 16, '#0b0b23', '#2a2a5a')
  stars(c, f, 14, 8)
  local bursts = { { 12, 5, C.gold }, { 32, 3, C.cyan }, { 52, 6, '#ff77a8' }, { 22, 9, C.lime } }
  for i, b in ipairs(bursts) do
    local t = (f + i * 3) % 9
    if t > 0 and t < 7 then
      for k = 0, 7 do
        local a = k * math.pi / 4
        c:set(b[1] + math.cos(a) * t, b[2] + math.sin(a) * t * 0.7, t > 4 and P.mix(b[3], '#2a2a5a', 0.5) or b[3])
      end
    end
  end
  castle(c, 26, 17, C.slate, f)
  ground(c, 17, C.lime, C.green)
end

function M.scenes.void(c, f)
  c:fill('#07060d')
  local r = R(31)
  for i = 1, 40 do
    local x, y = r(c.w), r(c.h)
    c:set((x + f * (i % 3)) % c.w, y, (i + f) % 5 == 0 and '#5d3a8a' or '#1e1530')
  end
  local glow = f % 4 < 2 and '#8f4bc4' or '#5d3a8a'
  c:rect(26, 3, 12, 14, '#0d0a14')
  for y = 3, 16 do
    c:set(25, y, glow)
    c:set(38, y, glow)
  end
  c:rect(25, 2, 14, 1, glow)
  c:set(35, 10, C.gold)
end

function M.scenes.mirrors(c, f)
  c:gradient(0, 16, '#141a2e', '#2a3558')
  for i, x in ipairs({ 2, 22, 42 }) do
    c:rect(x, 1, 18, 15, C.gold)
    c:rect(x + 1, 2, 16, 13, '#9fc4e8')
    c:rect(x + 1, 2, 16, 13, P.mix('#9fc4e8', '#dff3ff', ((f + i) % 6) / 10))
    local sx = x + 1 + (f * 2 + i * 5) % 16
    for y = 2, 14 do
      local px = sx + math.floor((y - 2) / 3)
      if px <= x + 16 then c:set(px, y, C.white) end
    end
  end
  for x = 0, c.w - 1 do
    for y = 17, 19 do
      c:set(x, y, (math.floor(x / 4) + y) % 2 == 0 and '#d8d8e8' or '#3a3a52')
    end
  end
end

function M.scenes.clock(c, f)
  c:gradient(0, 17, '#160f24', '#3a2350')
  c:circle(32, 8, 7, '#e8dcc0')
  c:circle(32, 8, 1, C.ink)
  for k = 0, 11 do
    local a = k * math.pi / 6
    c:set(32 + math.cos(a) * 6, 8 + math.sin(a) * 6, C.ink)
  end
  local a = f * 0.35
  for r = 1, 5 do
    c:set(32 + math.cos(a) * r, 8 + math.sin(a) * r, C.red)
  end
  for r = 1, 3 do
    c:set(32 + math.cos(a / 12) * r, 8 + math.sin(a / 12) * r, C.ink)
  end
  for _, g in ipairs({ { 8, 6, 1 }, { 56, 11, -1 } }) do
    c:circle(g[1], g[2], 4, '#8b6a3a')
    c:circle(g[1], g[2], 1, '#3a2350')
    for k = 0, 5 do
      local t = k * math.pi / 3 + f * 0.3 * g[3]
      c:set(g[1] + math.cos(t) * 5, g[2] + math.sin(t) * 5, '#c8a26b')
    end
  end
  c:rect(0, 17, c.w, 3, '#2a1d3a')
end

function M.scenes.forge(c, f)
  c:gradient(0, 17, '#1a0a08', '#4a1a10')
  local r = R(f + 5)
  for _ = 1, 10 do
    c:set(20 + r(24), 2 + r(10), ({ C.gold, C.orange, '#ff4422' })[r(3) + 1])
  end
  c:rect(24, 12, 16, 3, '#5a5a6a')
  c:rect(28, 15, 8, 2, '#3a3a4a')
  c:rect(22, 11, 20, 1, '#7a7a8a')
  for x = 4, 16 do
    local h = 3 + (x + f) % 4
    c:rect(x, 17 - h, 1, h, (x + f) % 3 == 0 and C.gold or C.orange)
  end
  ground(c, 17, '#3a1a10', '#22100a')
end

function M.scenes.echo(c, f)
  c:gradient(0, 17, '#06141f', '#0f2f45')
  for _, x in ipairs({ 6, 14, 50, 58 }) do
    for y = 0, 6 do
      c:rect(x - math.floor(y / 2), 17 - y * 2, 1 + y, 2, y % 2 == 0 and C.cyan or C.sky)
    end
  end
  local t = f % 8
  for k = 0, 15 do
    local a = k * math.pi / 8
    c:set(32 + math.cos(a) * t * 2, 9 + math.sin(a) * t, t < 6 and '#5fd0ff' or '#1f5f7f')
  end
  ground(c, 17, '#1f4f6f', '#0a2030')
end

function M.scenes.archive(c, f)
  c:gradient(0, 17, '#071a1a', '#123a3a')
  local books = { C.red, C.gold, C.blue, C.lime, C.orange }
  for i = 1, 7 do
    local x, y = 4 + i * 7, 3 + math.floor(math.sin((f + i * 2) * 0.6) * 2 + 2)
    c:rect(x, y, 4, 3, books[(i % #books) + 1])
    c:rect(x, y + 1, 4, 1, C.white)
  end
  c:circle(32, 13, 3, f % 2 == 0 and '#5fffd0' or '#2fbf9f')
  c:circle(32, 13, 1, C.white)
  ground(c, 17, '#1f5f5f', '#0a2a2a')
end

function M.scenes.study(c, f)
  c:fill('#1e140e')
  c:rect(44, 2, 12, 8, '#0b0b23')
  c:circle(50, 5, 2, '#fff3c4')
  c:rect(8, 12, 30, 2, '#5a3a22')
  c:rect(10, 14, 2, 4, '#5a3a22')
  c:rect(34, 14, 2, 4, '#5a3a22')
  c:rect(16, 10, 12, 2, C.white)
  c:rect(22, 10, 1, 2, '#c8a26b')
  c:rect(32, 9, 1, 3, C.white)
  c:set(32, 8, f % 3 == 0 and C.orange or C.gold)
  if f % 11 == 5 then c:rect(46, 3, 3, 6, '#000000') end
  ground(c, 18, '#2a1a10', '#2a1a10')
end

-- The File Tree: branches are folders, glowing fruit are files
function M.scenes.tree(c, f)
  c:gradient(0, 16, '#41a6f6', '#c9f0ff')
  c:rect(30, 6, 4, 11, '#6b4426')
  for _, b in ipairs({ { 22, 8, 8 }, { 34, 6, 9 }, { 25, 4, 6 }, { 34, 10, 6 } }) do
    c:rect(b[1], b[2], b[3], 1, '#6b4426')
  end
  for _, blob in ipairs({ { 24, 5, 6 }, { 38, 5, 6 }, { 31, 2, 6 }, { 26, 8, 4 }, { 38, 9, 4 } }) do
    c:circle(blob[1], blob[2], blob[3], (blob[1] + blob[2]) % 2 == 0 and C.green or '#2e9e58')
  end
  local fruit = { { 22, 6 }, { 27, 3 }, { 35, 2 }, { 41, 6 }, { 30, 9 }, { 39, 11 } }
  for i, p in ipairs(fruit) do
    c:rect(p[1], p[2], 2, 2, (i + f) % 6 == 0 and C.white or ({ C.red, C.gold, C.orange })[i % 3 + 1])
  end
  ground(c, 17, C.lime, C.green)
end

local positions = { hero = { 5, 3 }, wizard = { 46, 1 }, king = { 43, 1 }, stranger = { 46, 1 } }

-- Draws the characters on stage; the speaking one bobs, the hero follows your key presses
function M.cast(c, page, f, stage)
  stage = stage or {}
  for _, who in ipairs(page.cast or {}) do
    local s, pos = M.sprites[who], positions[who]
    local x, y = pos[1], pos[2] - ((page.who == who and f % 2 == 1) and 1 or 0)
    if who == 'hero' then
      x, y = x + (stage.dx or 0), y + (stage.dy or 0)
    end
    local pal = s.pal
    if who == 'stranger' and f % 3 == 0 then pal = vim.tbl_extend('force', pal, { e = '#ff2a2a' }) end
    c:sprite(x, y, s.rows, pal, who == 'wizard' or who == 'king' or who == 'stranger')
  end
end

-- Lights out: everything goes dark except a pair of glowing eyes
function M.blackout(c, f, page)
  c:dim('#020104', 0.93)
  local x, y = 47, 5
  if not vim.tbl_contains(page.cast or {}, 'stranger') then
    local r = R(f + 3)
    x, y = 10 + r(44), 2 + r(10)
  end
  local eye = f % 2 == 0 and '#ff2a2a' or C.cyan
  c:rect(x, y, 2, 1, eye)
  c:rect(x + 5, y, 2, 1, eye)
end

-- A sudden close-up of giant eyes in the dark
function M.scare(c, f)
  c:fill('#000000')
  for _, ex in ipairs({ 12, 38 }) do
    c:rect(ex, 6, 14, 7, '#e8e0d0')
    c:rect(ex + 1, 5, 12, 1, '#e8e0d0')
    c:rect(ex + 1, 13, 12, 1, '#e8e0d0')
    c:rect(ex + 4, 6, 6, 7, '#b00020')
    c:rect(ex + 6, 8, 2, 3, '#000000')
    for k = 0, 3 do
      c:set(ex + k * 4, 9 + (k % 2), '#b00020')
    end
  end
  if f % 2 == 1 then c:dim('#3a0008', 0.4) end
end

-- Glowing rune with its letter
function M.rune(c, f, letter)
  c:fill('#0d0a14')
  local glow = ({ '#8f4bc4', '#a970e0', '#c9a0ff', '#a970e0' })[f % 4 + 1]
  c:circle(15, 7, 7, '#2a1f3d')
  for a = 0, 23 do
    local t = a * math.pi / 12
    c:set(15 + math.cos(t) * 7, 7 + math.sin(t) * 7, glow)
  end
  c:text(13, 5, letter, C.white)
  local r = R(f + 9)
  for _ = 1, 6 do
    c:set(r(c.w), r(c.h), glow)
  end
end

function M.title(c, f)
  if c.h < 20 then
    c:gradient(0, c.h - 3, '#0b0b23', '#3b2a6b')
    stars(c, f, c.h - 4, 12)
    hills(c, c.h - 2, C.navy, 14, 3)
    ground(c, c.h - 2, C.lime, C.green)
    local word = 'VIMQUEST'
    local x = math.floor((c.w - P.text_width(word)) / 2)
    c:text(x, math.max(1, math.floor((c.h - 7) / 2)), word, function(r) return P.mix(C.gold, C.orange, (r - 1) / 4) end)
    c:sprite(3, c.h - 7 + (f % 8 < 4 and 0 or 1), M.sprites.gem.rows, M.sprites.gem.pal)
    c:sprite(c.w - 12, c.h - 5, M.sprites.key.rows, M.sprites.key.pal)
    return
  end
  c:gradient(0, 18, '#0b0b23', '#3b2a6b')
  stars(c, f, 16, 12)
  hills(c, 19, C.navy, 14)
  ground(c, 19, C.lime, C.green)
  local word = 'VIMQUEST'
  local x = math.floor((c.w - P.text_width(word)) / 2)
  c:rect(x - 2, 0, P.text_width(word) + 4, 7, '#14121f')
  c:text(x, 1, word, function(r) return P.mix(C.gold, C.orange, (r - 1) / 4) end)
  c:sprite(1, 6, M.sprites.hero.rows, M.sprites.hero.pal)
  c:sprite(48, 4, M.sprites.wizard.rows, M.sprites.wizard.pal, true)
  c:sprite(24 + (f % 8 < 4 and 0 or 1), 12, M.sprites.gem.rows, M.sprites.gem.pal)
  c:sprite(33, 13, M.sprites.key.rows, M.sprites.key.pal)
end

function M.clear(c, f, word)
  c:fill('#14121f')
  local bursts = { { 6, 4, C.gold }, { 42, 3, C.cyan }, { 24, 11, '#ff77a8' }, { 40, 11, C.lime } }
  for i, b in ipairs(bursts) do
    local t = (f + i * 2) % 8
    if t > 0 and t < 6 then
      for k = 0, 7 do
        local a = k * math.pi / 4
        c:set(b[1] + math.cos(a) * t, b[2] + math.sin(a) * t * 0.7, b[3])
      end
    end
  end
  local x = math.floor((c.w - P.text_width(word)) / 2)
  c:text(x, 4 + (f % 4 == 0 and -1 or 0), word, function(r) return P.mix(C.gold, C.orange, (r - 1) / 4) end)
end

function M.hurt(c, f)
  c:fill('#1f0a17')
  local s = M.sprites.king
  local pal = s.pal
  if f % 2 == 1 then
    pal = {}
    for k in pairs(s.pal) do
      pal[k] = C.white
    end
  end
  c:sprite(math.floor((c.w - 19) / 2) + (f % 2 == 0 and 1 or -1), 1, s.rows, pal)
end

-- End credits: fireworks, the hero, and whoever is being credited right now
function M.credits(c, f, guest)
  M.scenes.victory(c, f)
  M.cast(c, { cast = { 'hero' }, who = 'hero' }, f)
  local s = M.sprites[guest]
  if not s or guest == 'hero' then return end
  local pos = positions[guest]
  if pos then
    c:sprite(pos[1], pos[2] - f % 2, s.rows, s.pal, true)
  else
    c:sprite(44, 11 - (f % 4 < 2 and 0 or 1), s.rows, s.pal)
  end
end

return M
