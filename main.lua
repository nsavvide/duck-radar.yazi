local shell = os.getenv("SHELL"):match(".*/(.*)")
local get_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)
local fail = function(s, ...)
  ya.notify { title = "Duck Radar", content = string.format(s, ...), timeout = 5, level = "error" }
end

local function entry()
  ya.dbg("Duck Radar starting")
  local _permit = ya.hide()

  local home = os.getenv("HOME")

  local cmd = "find '" .. home .. "/Downloads' " ..
      "'" .. home .. "/Documents' " ..
      "'" .. home .. "/Desktop' " ..
      "'" .. home .. "/Pictures' " ..
      "-maxdepth 3 " ..
      "-type f " ..
      "-mtime -7 " ..
      "-not -path '*/.*' " ..
      "-not -path '*/node_modules/*' " ..
      "-not -path '*/.git/*' " ..
      "-printf '%T@ %p\\n' 2>/dev/null " ..
      "| sort -rn " ..
      "| head -200 " ..
      "| cut -d' ' -f2- " ..
      "| fzf " ..
      "--prompt='Recent File> ' " ..
      "--preview='bat --color=always --style=numbers --line-range :100 {} 2>/dev/null || ls -lh {}' " ..
      "--preview-window='right:60%:wrap' " ..
      "--header='Enter=COPY • Ctrl-X=MOVE • Sorted by modification time' " ..
      "--bind='ctrl-d:preview-down,ctrl-u:preview-up' " ..
      "--expect='enter,ctrl-x'" -- Keeps the ability to distinguish Move vs Copy

  ya.dbg("Running search")

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

  -- lines[1] is the key (enter or ctrl-x)
  -- lines[2] is the file path
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

return { entry = entry }
