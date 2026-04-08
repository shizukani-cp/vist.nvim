# vist.nvim

The extensible buffer-to-action engine for Neovim.

## Philosophy

vist.nvim is not a plugin for end-users, but a framework for plugin developers. 
It provides a minimal scaffolding to bridge the gap between "buffer content" and "programmable actions" 
by leveraging `acwrite` and `extmarks`.

## Features

- **Sync by Writing**: Map buffer save operations (`:w`) to custom logic.
- **ID Persistence**: Tracks items using extmarks, keeping them identified even after line moves or deletions.
- **Zero Dependencies**: Pure Lua and Neovim API only.
- **Visual Overlays**: Native support for icons using virtual text without polluting the actual buffer content.

## Installation

Using lazy.nvim:
```lua
{ "shizukani-cp/vist.nvim" }
```

## Quick Start

```lua
local vist = require("vist.core")

vist.open({
    bufname = function() return "VIST_EXAMPLE" end,
    list = function()
        return {
            { id = 101, display = "Item A", icon = "A" },
            { id = 102, display = "Item B", icon = "B" },
        }
    end,
    open_item = function(id, line)
        print("Selected ID: " .. id)
    end
})
```

See `:help vist.txt` for full API documentation.
