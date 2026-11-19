-- Pixel canvas drawn with half-block characters (each cell shows 2 vertical pixels)
local M = {}

local cache = {}
vim.api.nvim_create_autocmd('ColorScheme', { callback = function() cache = {} end })

local function pair(top, bot)
  local name = 'VQPx' .. top:sub(2) .. bot:sub(2)
  if not cache[name] then
    vim.api.nvim_set_hl(0, name, { fg = top, bg = bot })
    cache[name] = true
  end
  return name
end

local function rgb(c) return tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) end

function M.mix(a, b, t)
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  local f = function(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return ('#%02x%02x%02x'):format(f(r1, r2), f(g1, g2), f(b1, b2))
end

-- Deterministic pseudo-random generator so scenes look the same every frame
function M.rng(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n
  end
end

local Canvas = {}
Canvas.__index = Canvas

function M.new(w, h, color)
  local c = setmetatable({ w = w, h = h, px = {} }, Canvas)
  c:fill(color or '#000000')
  return c
end

function Canvas:set(x, y, color)
  x, y = math.floor(x), math.floor(y)
  if color and x >= 0 and y >= 0 and x < self.w and y < self.h then self.px[y * self.w + x + 1] = color end
end

function Canvas:get(x, y) return self.px[y * self.w + x + 1] end

function Canvas:fill(color)
  for i = 1, self.w * self.h do
    self.px[i] = color
  end
end

function Canvas:rect(x, y, w, h, color)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do
      self:set(xx, yy, color)
    end
  end
end

function Canvas:gradient(y0, y1, top, bottom)
  for y = y0, y1 do
    self:rect(0, y, self.w, 1, M.mix(top, bottom, (y - y0) / math.max(1, y1 - y0)))
  end
end

function Canvas:circle(cx, cy, r, color)
  for y = -r, r do
    for x = -r, r do
      if x * x + y * y <= r * r + r * 0.6 then self:set(cx + x, cy + y, color) end
    end
  end
end

-- Draws a sprite given as rows of palette characters ('.' or unknown = transparent)
function Canvas:sprite(x, y, rows, pal, flip, scale)
  scale = scale or 1
  for r, row in ipairs(rows) do
    local n = #row
    for i = 1, n do
      local col = pal[row:sub(i, i)]
      if col then
        local px = flip and n - i or i - 1
        self:rect(x + px * scale, y + (r - 1) * scale, scale, scale, col)
      end
    end
  end
end

-- Fades every pixel toward a color, used for blackouts
function Canvas:dim(color, t)
  for i = 1, self.w * self.h do
    self.px[i] = M.mix(self.px[i], color, t)
  end
end

M.font = {
  A = { '.XXX.', 'X...X', 'XXXXX', 'X...X', 'X...X' },
  C = { '.XXXX', 'X....', 'X....', 'X....', '.XXXX' },
  D = { 'XXXX.', 'X...X', 'X...X', 'X...X', 'XXXX.' },
  E = { 'XXXXX', 'X....', 'XXXX.', 'X....', 'XXXXX' },
  G = { '.XXXX', 'X....', 'X..XX', 'X...X', '.XXXX' },
  H = { 'X...X', 'X...X', 'XXXXX', 'X...X', 'X...X' },
  I = { 'XXXXX', '..X..', '..X..', '..X..', 'XXXXX' },
  K = { 'X...X', 'X..X.', 'XXX..', 'X..X.', 'X...X' },
  L = { 'X....', 'X....', 'X....', 'X....', 'XXXXX' },
  M = { 'X...X', 'XX.XX', 'X.X.X', 'X...X', 'X...X' },
  N = { 'X...X', 'XX..X', 'X.X.X', 'X..XX', 'X...X' },
  O = { '.XXX.', 'X...X', 'X...X', 'X...X', '.XXX.' },
  P = { 'XXXX.', 'X...X', 'XXXX.', 'X....', 'X....' },
  Q = { '.XXX.', 'X...X', 'X.X.X', 'X..X.', '.XX.X' },
  R = { 'XXXX.', 'X...X', 'XXXX.', 'X..X.', 'X...X' },
  S = { '.XXXX', 'X....', '.XXX.', '....X', 'XXXX.' },
  T = { 'XXXXX', '..X..', '..X..', '..X..', '..X..' },
  U = { 'X...X', 'X...X', 'X...X', 'X...X', '.XXX.' },
  V = { 'X...X', 'X...X', 'X...X', '.X.X.', '..X..' },
  W = { 'X...X', 'X...X', 'X.X.X', 'XX.XX', 'X...X' },
  X = { 'X...X', '.X.X.', '..X..', '.X.X.', 'X...X' },
  Y = { 'X...X', '.X.X.', '..X..', '..X..', '..X..' },
  ['!'] = { '..X..', '..X..', '..X..', '.....', '..X..' },
  [' '] = { '.....', '.....', '.....', '.....', '.....' },
}

function M.text_width(str) return #str * 6 - 1 end

-- Draws pixel-font text; color may be a function(row) for gradients
function Canvas:text(x, y, str, color, shadow)
  for pass = shadow and 1 or 2, 2 do
    for i = 1, #str do
      local g = M.font[str:sub(i, i)]
      for r, row in ipairs(g or {}) do
        for k = 1, #row do
          if row:sub(k, k) == 'X' then
            local px, py = x + (i - 1) * 6 + k - 1, y + r - 1
            if pass == 1 then
              self:set(px + 1, py + 1, shadow)
            else
              self:set(px, py, type(color) == 'function' and color(r) or color)
            end
          end
        end
      end
    end
  end
end

-- Writes the canvas into buf at the given row, merging runs of identical cells into one highlight
function M.draw(buf, ns, c, row)
  local rows = c.h / 2
  local line = string.rep('▀', c.w)
  local lines = {}
  for i = 1, rows do
    lines[i] = line
  end
  local mod = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, row, row + rows, false, lines)
  vim.bo[buf].modifiable = mod
  vim.api.nvim_buf_clear_namespace(buf, ns, row, row + rows)
  for r = 0, rows - 1 do
    local x = 0
    while x < c.w do
      local top, bot = c.px[2 * r * c.w + x + 1], c.px[(2 * r + 1) * c.w + x + 1]
      local e = x + 1
      while e < c.w and c.px[2 * r * c.w + e + 1] == top and c.px[(2 * r + 1) * c.w + e + 1] == bot do
        e = e + 1
      end
      vim.api.nvim_buf_set_extmark(buf, ns, row + r, x * 3, { end_col = e * 3, hl_group = pair(top, bot) })
      x = e
    end
  end
end

return M
