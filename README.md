# duck-radar.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin for quickly finding and copying/moving recently modified files to your current directory.

Duck Radar scans the current directory plus any directories you configure for files modified in the last 7 days and presents them in an interactive fzf picker with syntax-highlighted previews. Perfect for grabbing that file you just downloaded or worked on without navigating through folders.

## Requirements

- `fzf` - Interactive fuzzy finder
- `bat` - Syntax highlighting for file previews (optional but recommended)

Install on most systems:

**macOS**

```bash
brew install fzf bat
```

**Arch Linux**

```bash
sudo pacman -S fzf bat
```

**Ubuntu/Debian**

```bash
sudo apt install fzf bat
```

## Installation

```bash
ya pkg add nsavvide/duck-radar
```

Or manually: place the plugin directory at `~/.config/yazi/plugins/duck-radar.yazi/`

## Usage

Add a keybinding to your `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = "<C-r>" # or your preferred key
run = "plugin duck-radar"
desc = "🦆 Duck Radar - Recent Files"
```

## Features

- **Smart Search**: Finds files modified in the last 7 days across the current directory and your configured `dirs`
- **Fast Performance**: Limited depth (3 levels) and top 200 results for instant response
- **Copy, Move, or Jump**: Press `Enter` to jump to the file in place, `Ctrl-Y` to copy it, `Ctrl-X` to move it
- **Rich Preview**: Syntax-highlighted file contents with bat
- **Intelligent Filtering**: Exclude files/dirs by name or absolute path via `excludePatterns` (none excluded by default).

## Keybindings

Inside the fzf picker:

- `j/k` or `↑/↓` - Navigate
- `Enter` - **Jump** to the selected file in place (reveals it in Yazi without copying/moving)
- `Ctrl-Y` - **Copy** selected file to current directory (or into the paste buffer, see `pasteBuffer` below)
- `Ctrl-X` - **Move** selected file to current directory (or into the paste buffer, see `pasteBuffer` below)
- `Ctrl-D/U` - Scroll preview down/up
- `Esc` or `Ctrl-C` - Cancel

## Setup

Add the following to your `~/.config/yazi/init.lua` (all fields are optional; defaults shown unless noted):

```lua
require("duck-radar"):setup({
    -- Dirs to search. Empty by default — set these, or rely on includeCwd
    dirs = {
        -- os.getenv("HOME") .. "/Downloads",
    },
    -- Patterns to exclude from search. Plain names (e.g. "node_modules")
    -- match that file/dir at any depth. Patterns starting with "/" are
    -- absolute paths (e.g. os.getenv("HOME") .. "/Library") and exclude
    -- everything under that exact directory. None excluded by default.
    excludePatterns = {},
    -- 'find' or 'fd'
    app = "find",
    -- Only show files modified within this many days
    changedWithin = 7,
    -- Max depth to search. 2 for faster, 4 for deeper search
    maxDepth = 3,
    -- Amount of results to show
    resultLimit = 200,
    -- If true, Copy/Move don't paste immediately — they yank the file into
    -- Yazi's own clipboard instead, so you can press 'p' to paste it yourself
    pasteBuffer = false,
    -- Whether to also search the current directory
    includeCwd = true,
})
```

Example using `fd`, extra directories search:

```lua
require("duck-radar"):setup({
    -- Dirs to search (no defaults)
    dirs = {
        -- Launch directory
        os.getenv("PWD"),
        -- "/path/to/extra/dir",
        os.getenv("HOME") .. "/Downloads",
        os.getenv("HOME") .. "/Documents",
        os.getenv("HOME") .. "/Desktop",
        os.getenv("HOME") .. "/Pictures",
    },
    -- filter  by patterns
    excludePatterns = {
        ".git",
        "node_modules",
        ".DS_Store",
        -- absolute path to exclude
        os.getenv("HOME") .. "/Library",
    },
    -- 'find' or 'fd'
    app = "fd",
    -- Time range in days
    changedWithin = 7,
    -- Max depth to search. 2 for faster, 4 for deeper search
    maxDepth = 2,
    -- Amount of results to show
    resultLimit = 200,
    -- Copy to the buffer only when you use ctrl-y and ctrl-x, then you can paste with p.
    pasteBuffer = true,
    -- Include current working directory
    includeCwd = true,
})
```

## Migrating

If you used Duck Radar before `dirs` became configurable:

- **There are no default directories anymore.** With no `dirs` set, the plugin only
  searches the current directory (via `includeCwd`). Add the old defaults back
  explicitly if you want them:
  ```lua
  dirs = {
      os.getenv("HOME") .. "/Downloads",
      os.getenv("HOME") .. "/Documents",
      os.getenv("HOME") .. "/Desktop",
      os.getenv("HOME") .. "/Pictures",
  },
  ```
- **`changedWithin` is now a plain number of days** for both `find` and `fd`.
  The old `"7d"` string still works (the trailing `d` is stripped), but prefer `7`.
- **Hidden files are now included.** The old `find` path silently skipped dotfiles;
  add the names you don't want to `excludePatterns` (e.g. `".git"`, `".cache"`).

## Acknowledgements

- [Yazi](https://github.com/sxyazi/yazi) - The blazing fast terminal file manager 🦆
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [fr.yazi](https://github.com/yazi-rs/plugins/tree/main/fr.yazi) - Inspiration for the fzf integration pattern

## License

MIT

---

**Duck Radar** - Your recent files are always within reach 🦆✨
