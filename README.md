# Aurore

An AI-powered Neovim plugin for enhanced development workflow.

## Installation

You can install Aurore using your preferred package manager:

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'harryoltmans/aurore',
    config = function()
        require('aurore').setup()
    end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'harryoltmans/aurore',
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

## Usage

Describe the main features and how to use them here.

## Configuration

List available configuration options and their default values.

## Commands

Document available commands and their usage.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details
