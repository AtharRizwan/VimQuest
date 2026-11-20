-- Compiles each Lua file given on the command line without running it; prints syntax errors
for _, f in ipairs(arg) do
  local ok, err = loadfile(f)
  if not ok then print(err) end
end
