local M = {}

local shell = os.getenv("SHELL"):match(".*/(.*)")
local get_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)
local fail = function(s, ...)
  ya.notify { title = "Duck Radar", content = string.format(s, ...), timeout = 5, level = "error" }
end

local apply_config = ya.sync(function(st, cfg)
  cfg = cfg or {}
  local dirs = {}
  for i = 1, #(cfg.dirs or {}) do
    dirs[i] = "'" .. cfg.dirs[i]:gsub("'", "'\\''") .. "'"
  end

  st.dirs = table.concat(dirs, " ")
  st.app = cfg.app or "find"
  -- accepts 7, "7" or the legacy "7d"
  st.changedWithin = tonumber(tostring(cfg.changedWithin or 7):match("^%s*(%d+)")) or 7
  st.maxDepth = cfg.maxDepth or "3"
  st.resultLimit = cfg.resultLimit or "200"
  st.pasteBuffer = cfg.pasteBuffer or false
  st.includeCwd = cfg.includeCwd
  if st.includeCwd == nil then st.includeCwd = true end

  local excludePatterns = cfg.excludePatterns or {}
  local excludeNames, excludeAbsPaths = {}, {}
  for i = 1, #excludePatterns do
    local p = excludePatterns[i]
    local safe = "'" .. p:gsub("'", "'\\''") .. "'"
    if p:sub(1, 1) == "/" then
      excludeAbsPaths[#excludeAbsPaths + 1] = safe
    else
      excludeNames[#excludeNames + 1] = safe
    end
  end
  st.excludeNames = excludeNames
  st.excludeAbsPaths = excludeAbsPaths
end)

-- Neither `fd --exclude` nor `find -path` reliably match absolute paths
-- across multiple search roots, so absolute-path patterns are filtered out
-- with a `grep -v` prefix match after the search instead of natively.
local function abs_path_filter(excludeAbsPaths)
  local pipe = ""
  for i = 1, #excludeAbsPaths do
    pipe = pipe .. "| grep -vF " .. excludeAbsPaths[i] .. " "
  end
  return pipe
end

local function get_extra_cmd(resultLimit)
  return "| sort -rn " ..
      "| cut -d' ' -f2- " ..
      -- dedupe before `head` so duplicates from overlapping roots don't eat result slots
      "| awk '!seen[$0]++' " ..
      "| head -" .. resultLimit .. " " ..
      "| fzf " ..
      "--prompt='Recent File> ' " ..
      "--preview='bat --color=always --style=numbers --line-range :100 {} 2>/dev/null || ls -lh {}' " ..
      "--preview-window='right:60%:wrap' " ..
      "--header='enter=jump • ctrl-y=copy • ctrl-x=move • Sorted by modification time' " ..
      "--bind='ctrl-d:preview-down,ctrl-u:preview-up' " ..
      "--expect='enter,ctrl-x,ctrl-y'"
end

function M:setup(cfg)
  apply_config(cfg)
end

local get_findApp = ya.sync(function(st) return st.app end)
local get_pasteBuffer = ya.sync(function(st) return st.pasteBuffer end)

local get_cmd_fd = ya.sync(function(st)
  local dirs = st.dirs .. " "
  local changedWithin = st.changedWithin .. "d"
  local maxDepth = st.maxDepth
  local resultLimit = st.resultLimit
  local searchRoot = st.includeCwd and (tostring(cx.active.current.cwd) .. " ") or ""

  local excludeFlags = {}
  for i = 1, #st.excludeNames do
    excludeFlags[i] = "--exclude " .. st.excludeNames[i]
  end
  local excludes = table.concat(excludeFlags, " ") .. " "
  local absFilter = abs_path_filter(st.excludeAbsPaths)

  -- Uses a portable sh loop to print "<mtime> <path>", falling back to BSD stat on macOS
  return "fd " ..
      ". " ..
      dirs ..
      searchRoot ..
      "--max-depth " .. maxDepth .. " " ..
      "--type f " ..
      "--changed-within " .. changedWithin .. " " ..
      "--hidden --no-ignore " ..
      excludes ..
      "--exec-batch sh -c 'for f; do printf \"%s %s\\n\" \"$(stat -c %Y \"$f\" 2>/dev/null || stat -f %m \"$f\")\" \"$f\"; done' sh 2>/dev/null " ..
      absFilter ..
      get_extra_cmd(resultLimit)
end)

local get_cmd_find = ya.sync(function(st)
  local dirs = st.dirs .. " "
  local changedWithin = st.changedWithin
  local maxDepth = st.maxDepth
  local resultLimit = st.resultLimit
  local searchRoot = st.includeCwd and (tostring(cx.active.current.cwd) .. " ") or ""

  -- `-prune` skips the whole subtree, unlike `-not -name` which only hides it from output
  local excludes = ""
  if #st.excludeNames > 0 then
    local names = {}
    for i = 1, #st.excludeNames do
      names[i] = "-name " .. st.excludeNames[i]
    end
    excludes = "\\( " .. table.concat(names, " -o ") .. " \\) -prune -o "
  end
  local absFilter = abs_path_filter(st.excludeAbsPaths)

  -- Uses a portable sh loop to print "<mtime> <path>" instead of GNU-only `-printf`,
  -- falling back to BSD stat on macOS
  return "find " ..
      dirs ..
      searchRoot ..
      "-maxdepth " .. maxDepth .. " " ..
      excludes ..
      "-type f " ..
      "-mtime -" .. changedWithin .. " " ..
      "-exec sh -c 'for f; do printf \"%s %s\\n\" \"$(stat -c %Y \"$f\" 2>/dev/null || stat -f %m \"$f\")\" \"$f\"; done' sh {} + 2>/dev/null " ..
      absFilter ..
      get_extra_cmd(resultLimit)
end)

local reveal_file = ya.sync(function(_, file)
  ya.emit("reveal", { file })
end)

local yank_file = ya.sync(function(_, file, cut)
  local cwd = tostring(cx.active.current.cwd)
  ya.emit("reveal", { file })
  ya.emit("yank", { cut = cut })
  ya.emit("cd", { cwd })
end)

function M:entry()
  ya.dbg("Duck Radar starting")
  if not get_findApp() then apply_config({}) end
  local _permit = ui.hide()

  local app = get_findApp()
  if app ~= "find" and app ~= "fd" then
    fail("Invalid app '%s': use 'find' or 'fd'", app or "nil")
    app = "find"
  end
  local cmd = app == "find" and get_cmd_find() or get_cmd_fd()

  ya.dbg("Running search with " .. app)

  local child, err = Command(shell)
      :arg("-c")
      :arg(cmd)
      :stdin(Command.INHERIT)
      :stdout(Command.PIPED)
      :stderr(Command.INHERIT)
      :spawn()

  if not child then
    return fail("Command failed: %s", err)
  end

  local output, err = child:wait_with_output()
  if not output or output.status.code ~= 0 then return end

  local lines = {}
  for line in output.stdout:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  if #lines < 2 then
    return ya.notify { title = "Duck Radar", content = "No file selected", timeout = 3 }
  end

  local action = "jump"
  if lines[1] == "ctrl-x" then
    action = "move"
  elseif lines[1] == "ctrl-y" then
    action = "copy"
  end
  local file = lines[2]
  local cwd = get_cwd()

  ya.dbg("Action: " .. action .. " on " .. file)

  if action == "jump" then
    return reveal_file(file)
  end

  if get_pasteBuffer() then
    yank_file(file, action == "move")
    return ya.notify {
      title = "Duck Radar",
      content = string.format("%s for paste — press 'p' to paste", action == "move" and "Cut" or "Copied"),
      timeout = 3
    }
  end

  local safe_file = "'" .. file:gsub("'", "'\\''") .. "'"
  local cmd_verb = action == "move" and "mv" or "cp -r"
  local exec_cmd = cmd_verb .. " " .. safe_file .. " '" .. cwd .. "/' 2>&1"

  local result = Command(shell):arg("-c"):arg(exec_cmd):output()

  if result and result.status.success then
    ya.notify {
      title = "Duck Radar",
      content = string.format("%s 1 file!", action == "move" and "Moved" or "Copied"),
      timeout = 3
    }
  else
    return fail(action .. " failed")
  end
end

return M
