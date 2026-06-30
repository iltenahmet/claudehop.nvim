# claudehop.nvim

A three-pane [Claude Code](https://www.claude.com/product/claude-code) panel for
Neovim where **every file and symbol in Claude's output is clickable and
keyboard-hoppable**. Read a reply, press one key, and land on the exact spot in
your code.

> Status: **v0**. This first version gives you the core experience — a real
> Claude Code session rendered in a normal Neovim buffer, with jump-to-location.
> See [Roadmap](#roadmap) for what comes next.

## Why this exists

Most editor integrations run the Claude Code terminal UI inside a split. That
works, but a terminal is a grid of characters: you cannot reliably click a file
name in it or jump to a function. claudehop takes the other path that the
official VS Code extension takes — it drives the real `claude` engine in the
background and renders the conversation into a normal buffer it fully controls.
Because the text is ours, we can attach the exact `{file, line}` behind every
reference and let you jump to it by mouse or by keyboard.

It drives **your own installed `claude` binary**, so any new skill, slash
command, MCP server, or memory file you add works immediately — there is no
feature list in this plugin to keep up to date.

## Features (v0)

- **Three-pane layout** — your editor on the left, the Claude conversation on
  the right, a prompt box below it.
- **Real Claude Code session** — runs `claude` in streaming JSON mode, so you
  get the full engine: skills, slash commands, MCP, and `CLAUDE.md` memory.
- **Clickable references** — file paths and `file:line` locations in the output
  are highlighted. Press `<CR>` (or double-click) to jump to them in the editor.
- **Keyboard hop** — press `f` in the conversation to label every reference on
  screen with a single key, then press that key to jump. No mouse needed.
- **Reference stepping** — `<Tab>` / `<S-Tab>` move between references.
- **Multiple sessions** — run several conversations at once and switch between
  them with `<C-l>` / `<C-h>`; start a new one with `<C-n>`.

## Requirements

- Neovim 0.10+
- The `claude` CLI on your `PATH` ([install Claude Code](https://docs.claude.com/en/docs/claude-code/setup))

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "iltenahmet/claudehop.nvim",
  opts = {},
  keys = {
    { "<leader>cc", "<cmd>ClaudeHop<cr>", desc = "Toggle Claude" },
  },
  cmd = { "ClaudeHop", "ClaudeHopOpen", "ClaudeHopNew", "ClaudeHopSend" },
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "iltenahmet/claudehop.nvim",
  config = function()
    require("claudehop").setup()
  end,
})
```

## Usage

| Command | What it does |
| --- | --- |
| `:ClaudeHop` | Toggle the panel |
| `:ClaudeHopOpen` | Open the panel |
| `:ClaudeHopNew` | Start a new session |
| `:ClaudeHopSend <text>` | Send a prompt to the active session |
| `:ClaudeHopLog` | Show the raw process log (what was sent and received) |

Type in the prompt box and press `<CR>` (normal mode) or `<C-s>` (insert mode)
to send.

### Keymaps inside the panel

| Key | Where | Action |
| --- | --- | --- |
| `<CR>` | conversation | Jump to the reference under the cursor |
| `f` | conversation | Label visible references, then jump by key |
| `<Tab>` / `<S-Tab>` | conversation | Next / previous reference |
| `<CR>` | prompt box (normal) | Send the prompt |
| `<C-s>` | prompt box (insert) | Send the prompt |
| `<C-n>` | either | New session |
| `<C-l>` / `<C-h>` | either | Next / previous session |

## Configuration

These are the defaults; pass any subset to `setup()`.

```lua
require("claudehop").setup({
  claude_cmd = "claude",          -- the Claude Code binary
  extra_args = {},                -- extra CLI args, e.g. { "--permission-mode", "acceptEdits" }
  include_partial_messages = true,-- stream replies as they are written

  layout = {
    position = "right",
    width = 0.42,                 -- fraction of columns the Claude side takes
    input_height = 6,             -- lines in the prompt box
  },

  keymaps = {
    jump = "<CR>",
    next_ref = "<Tab>",
    prev_ref = "<S-Tab>",
    hop = "f",
    submit = "<CR>",
    submit_insert = "<C-s>",
    new_session = "<C-n>",
    next_session = "<C-l>",
    prev_session = "<C-h>",
  },
})
```

## Troubleshooting

If a prompt produces no reply, run `:ClaudeHopLog`. It shows every line sent to
the `claude` process and every line received, including errors — which makes it
easy to see whether the binary started, what it emitted, and whether a line
failed to decode. Turn the log off with `vim.g.claudehop_debug = false`.

## Roadmap

claudehop drives the real engine, so config-level features (skills, commands,
MCP, memory) already work. The roadmap is about the editor experience:

- **IDE WebSocket bridge** — run the local server the official editors use, so
  Claude can open exact diffs, open files at a line, and read your selection.
- **Tool approval UI** — a generic approve / deny / choose panel for any
  permission prompt the engine raises.
- **Streaming text** — render replies token by token using partial events.
- **Session picker** — resume past conversations from disk.
- **Symbol-aware jumps** — resolve function and symbol names via the language
  server, not just file paths.
- **TUI fallback** — toggle any session into the real terminal UI for anything
  the custom panel does not render yet, so you are never behind the terminal.

See [docs/DESIGN.md](docs/DESIGN.md) for the architecture and the reasoning
behind these choices.

## License

MIT
