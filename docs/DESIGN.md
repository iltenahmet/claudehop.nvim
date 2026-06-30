# claudehop.nvim — design

This document explains how the plugin is built and why. It is meant for someone
who has not seen the earlier discussion.

## Goal

A Claude Code panel for Neovim that does three things existing plugins do not do
well together:

1. Switch between several Claude Code sessions easily.
2. A simple layout: the editor on the left, Claude on the right.
3. Every file name and symbol in Claude's output is clickable, and you can hop
   to any of them with the keyboard alone, landing on the exact spot in the
   editor.

## The core decision: render our own UI, do not embed the terminal

Claude Code has a terminal UI (the "TUI"). The easy path is to run that TUI in a
Neovim terminal split. We chose **not** to do that.

A terminal is a grid of characters. The text in it is not something we can
attach data to. To make a file name clickable there, we would have to scan the
visible rows with regular expressions, which breaks on scrolling, wrapping, and
resizing. Function names in the text have no file or line behind them at all.
Requirements 2 and 3 above are very hard on this path.

Instead we drive the Claude Code **engine** in the background and render the
conversation into a normal Neovim buffer that we fully control. Because we own
the text, we can attach the exact `{file, line}` behind every reference and jump
to it precisely. This is the same architecture the official VS Code extension
uses: it runs the CLI headlessly and draws its own panel.

## How we talk to the engine

We start the real `claude` binary in its streaming JSON mode:

```
claude --print --input-format stream-json --output-format stream-json --verbose
```

This keeps one long-lived process alive. We write user turns to its stdin as
single-line JSON objects, and read events back from its stdout, one JSON object
per line. Each session is one such process with its own buffers.

The relevant files:

- `stream.lua` — starts the process, splits stdout into whole JSON lines,
  decodes them, and sends user turns to stdin.
- `session.lua` — owns the list of sessions, their buffers, and switching.
- `render.lua` — turns each JSON event into lines in the conversation buffer.
- `refs.lua` — marks file references, and does the jump / step / hop actions.
- `ui.lua` — builds the three-pane layout and finds the editor window to jump
  into.
- `keymaps.lua` — buffer-local keys for the conversation and the prompt box.

## How a jump works

When Claude writes text, `render.lua` appends it and `refs.lua` scans each line
for two shapes:

- `path/to/file.ext:42` — a file with a line number.
- `path/to/file.ext` — a bare file path that contains a slash.

For each match we set an extmark over the text (which highlights it) and store
its jump target in a table keyed by the extmark id. When Claude calls a tool
that touches a file (Edit, Write, Read), we also mark the file path, and for an
edit we remember the first line of the new text so the jump can search for it.

To jump, we read the extmark under the cursor, switch to the editor window, open
the file, and move the cursor to the line (or search for the remembered text).

The `hop` action labels every reference currently on screen with a single key,
waits for one keypress, and jumps to the chosen one. This is the keyboard-only
way to reach any reference without stepping through them.

## Keeping up with the terminal automatically

A worry with rendering our own UI is falling behind the terminal when Claude
Code ships new features. We avoid this in three ways:

1. **Pass-through by default.** We drive the user's own `claude` binary and
   never keep a list of valid commands or skills. New slash commands, skills,
   MCP servers, and `CLAUDE.md` behaviour come from the engine and from files on
   disk, so they work the day the user upgrades, with no change here.
2. **Render by shape, never drop the unknown.** We render events by their shape.
   When a future version emits an event type we do not recognise, the plan is to
   show it plainly rather than hide it, so new output at least appears.
3. **A terminal fallback (planned).** A key will toggle any session into the
   real `claude` terminal UI for anything our panel does not render yet. The
   worst case for a brand-new feature is one keypress to use it in the terminal.

## What v0 leaves for later

- The IDE WebSocket bridge (exact diffs, open-file-at-line, selection sharing).
  The editor runs a small local WebSocket server that the CLI connects to. A
  pure-Lua reference exists in `coder/claudecode.nvim`.
- A generic tool-approval panel for permission prompts.
- Token-by-token streaming using partial message events.
- Resuming past sessions from the on-disk transcripts.
- Resolving symbol names through the language server, not just file paths.
