# Aurore

An AI-powered Neovim plugin for enhanced development workflow.

## Installation

You can install Aurore using your preferred package manager:

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'addanine/aurore.nvim',
    config = function()
        require('aurore').setup()
    end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'addanine/aurore.nvim',
    config = function()
        require('aurore').setup()
    end
}
```

## Setup

1. After installation, add the following to your Neovim configuration:

```lua
require('aurore').setup({
    -- Your configuration options here
})
```

2. Restart Neovim for changes to take effect
