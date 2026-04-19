local M = {}

local shell = os.getenv("SHELL"):match(".*/(.*)")
local get_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)
local fail = function(s, ...)
  ya.notify { title = "Duck Radar", content = string.format(s, ...), timeout = 5, level = "error" }
end

local apply_config = ya.sync(function(st, cfg)
  cfg = cfg or {}
  cfg.dirs = cfg.dirs or {}

  local homeDir = os.getenv("HOME")
  local dirs = {
    homeDir .. "/Downloads",
    homeDir .. "/Documents",
    homeDir .. "/Desktop",
    homeDir .. "/Pictures"
  }

  for i = 1, #cfg.dirs do
    dirs[#dirs + 1] = cfg.dirs[i]
  end

  for i = 1, #dirs do
    dirs[i] = "'" .. dirs[i]:gsub("'", "'\\''") .. "'"
  end

  st.dirs = table.concat(dirs, " ")
  st.app = cfg.app or "find"
  st.changedWithin = cfg.changedWithin
  st.maxDepth = cfg.maxDepth or "3"
  st.resultLimit = cfg.resultLimit or "200"
end)

function M:setup(cfg)
  apply_config(cfg)
end

local get_findApp = ya.sync(function(st) return st.app end)

local get_cmd_fd = ya.sync(function(st)
  local dirs = st.dirs .. " "
  local changedWithin = st.changedWithin or "7d"
  local maxDepth = st.maxDepth
  local resultLimit = st.resultLimit

  -- Uses a portable sh loop to print "<mtime> <path>", falling back to BSD stat on macOS
  return "fd " ..
      ". " ..
      dirs ..
      "--max-depth " .. maxDepth .. " " ..
      "--type f " ..
      "--changed-within " .. changedWithin .. " " ..
      "--hidden --no-ignore " ..
      "--exclude '.git' " ..
      "--exclude 'node_modules' " ..
      "--exec-batch sh -c 'for f; do printf \"%s %s\\n\" \"$(stat -c %Y \"$f\" 2>/dev/null || stat -f %m \"$f\")\" \"$f\"; done' sh " ..
      "| sort -rn " ..
      "| head -" .. resultLimit .. " " ..
      "| cut -d' ' -f2- " ..
      "| fzf " ..
      "--prompt='Recent File> ' " ..
      "--preview='bat --color=always --style=numbers --line-range :100 {} 2>/dev/null || ls -lh {}' " ..
      "--preview-window='right:60%:wrap' " ..
      "--header='Enter=COPY • Ctrl-X=MOVE • Sorted by modification time' " ..
      "--bind='ctrl-d:preview-down,ctrl-u:preview-up' " ..
      "--expect='enter,ctrl-x'"
end)

local get_cmd_find = ya.sync(function(st)
  local dirs = st.dirs .. " "
  local changedWithin = st.changedWithin or "7"
  local maxDepth = st.maxDepth
  local resultLimit = st.resultLimit

  return "find " ..
      dirs ..
      "-maxdepth " .. maxDepth .. " " ..
      "-type f " ..
      "-mtime -" .. changedWithin .. " " ..
      "-not -path '*/.*' " ..
      "-not -path '*/node_modules/*' " ..
      "-not -path '*/.git/*' " ..
      "-printf '%T@ %p\\n' 2>/dev/null " ..
      "| sort -rn " ..
      "| head -" .. resultLimit .. " " ..
      "| cut -d' ' -f2- " ..
      "| fzf " ..
      "--prompt='Recent File> ' " ..
      "--preview='bat --color=always --style=numbers --line-range :100 {} 2>/dev/null || ls -lh {}' " ..
      "--preview-window='right:60%:wrap' " ..
      "--header='Enter=COPY • Ctrl-X=MOVE • Sorted by modification time' " ..
      "--bind='ctrl-d:preview-down,ctrl-u:preview-up' " ..
      "--expect='enter,ctrl-x'"
end)

function M:entry()
  ya.dbg("Duck Radar starting")
  if not get_findApp() then apply_config({}) end
  local _permit = ya.hide()

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

  local action = lines[1] == "ctrl-x" and "move" or "copy"
  local file = lines[2]
  local cwd = get_cwd()

  ya.dbg("Action: " .. action .. " on " .. file)

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
