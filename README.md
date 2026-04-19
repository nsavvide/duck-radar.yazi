# duck-radar.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin for quickly finding and copying/moving recently modified files to your current directory.

Duck Radar scans your common directories (Downloads, Documents, Desktop) for files modified in the last 7 days and presents them in an interactive fzf picker with syntax-highlighted previews. Perfect for grabbing that file you just downloaded or worked on without navigating through folders.

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

- **Smart Search**: Finds files modified in the last 7 days across Downloads, Documents, Desktop
- **Fast Performance**: Limited depth (3 levels) and top 200 results for instant response
- **Copy or Move**: Press `Enter` to copy files, `Ctrl-X` to move them
- **Rich Preview**: Syntax-highlighted file contents with bat
- **Intelligent Filtering**: Automatically excludes `.git`, `node_modules`, cache directories.

## Keybindings

Inside the fzf picker:

- `j/k` or `↑/↓` - Navigate
- `Enter` - **Copy** selected files to current directory
- `Ctrl-X` - **Move** selected files to current directory
- `Ctrl-D/U` - Scroll preview down/up
- `Esc` or `Ctrl-C` - Cancel

## Setup

Add the following to your `~/.config/yazi/init.lua` (all fields are optional; defaults shown):

```lua
require("duck-radar"):setup({
    -- Extra dirs to search in addition to ~/Downloads, ~/Documents, ~/Desktop, ~/Pictures
    dirs = {
        -- "/path/to/extra/dir",
    },
    -- 'find' or 'fd'
    app = "find",
    -- Time range; when using fd, use its format (e.g. "7d") instead of find's (e.g. "7")
    changedWithin = "7",
    -- Max depth to search. 2 for faster, 4 for deeper search
    maxDepth = "3",
    -- Amount of results to show
    resultLimit = 200,
})
```

## Acknowledgements

- [Yazi](https://github.com/sxyazi/yazi) - The blazing fast terminal file manager 🦆
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [fr.yazi](https://github.com/yazi-rs/plugins/tree/main/fr.yazi) - Inspiration for the fzf integration pattern

## License

MIT

---

**Duck Radar** - Your recent files are always within reach 🦆✨
