-- snip: include code from the book's example projects so listings can never
-- drift from the shipping source.
--
--   {{< snip 10-crank/source/input.lua crank-aim >}}   -- a marked region
--   {{< snip 01-hello/source/main.lua >}}              -- the whole file
--
-- Regions are delimited in the source by marker comments:
--   -- snip: crank-aim
--   ...code...
--   -- endsnip
--
-- A missing file or region fails the render loudly.

local function readLines(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  return lines
end

local function isSnipMarker(line)
  local name = line:match("^%s*%-%-%s*snip:%s*(.-)%s*$")
  if name then return "start", name end
  if line:match("^%s*%-%-%s*endsnip%s*$") then return "stop" end
  return nil
end

local function extract(lines, region)
  local out, grabbing, found = {}, false, false
  for _, line in ipairs(lines) do
    local kind, name = isSnipMarker(line)
    if kind == "start" then
      if region and name == region then
        grabbing, found = true, true
      end
    elseif kind == "stop" then
      if grabbing then grabbing = false end
    elseif region then
      if grabbing then out[#out + 1] = line end
    else
      out[#out + 1] = line -- whole file, markers stripped
    end
  end
  if region and not found then return nil end
  -- trim leading/trailing blank lines
  while out[1] and not out[1]:match("%S") do table.remove(out, 1) end
  while out[#out] and not out[#out]:match("%S") do table.remove(out) end
  -- dedent to the shallowest non-blank line
  local minIndent
  for _, l in ipairs(out) do
    if l:match("%S") then
      local n = #(l:match("^[ \t]*"))
      if not minIndent or n < minIndent then minIndent = n end
    end
  end
  if minIndent and minIndent > 0 then
    for i, l in ipairs(out) do out[i] = l:sub(minIndent + 1) end
  end
  return table.concat(out, "\n")
end

return {
  ["snip"] = function(args, kwargs, meta)
    local rel = pandoc.utils.stringify(args[1] or "")
    local region = args[2] and pandoc.utils.stringify(args[2]) or nil
    if rel == "" then error("snip: missing file argument") end
    local root = (quarto and quarto.project and quarto.project.directory)
        or os.getenv("QUARTO_PROJECT_DIR") or "."
    local path = tostring(root) .. "/examples/" .. rel
    local lines = readLines(path)
    if not lines then error("snip: cannot read " .. path) end
    local code = extract(lines, region)
    if not code then
      error("snip: region '" .. tostring(region) .. "' not found in " .. path)
    end
    local fname = rel:match("([^/]+)$") or rel
    local block = pandoc.CodeBlock(code, pandoc.Attr("", { "lua" }, { filename = fname }))
    if quarto and quarto.doc and quarto.doc.is_format and quarto.doc.is_format("html") then
      -- reproduce Quarto's filename chip for computational cells
      return pandoc.Blocks({
        pandoc.Div({
          pandoc.Div({ pandoc.Plain({ pandoc.Str(fname) }) },
            pandoc.Attr("", { "code-with-filename-file" })),
          block,
        }, pandoc.Attr("", { "code-with-filename" })),
      })
    end
    return pandoc.Blocks({ block })
  end,
}
