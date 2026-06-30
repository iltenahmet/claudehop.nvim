-- Default settings for claudehop.nvim.
-- Anything here can be overridden by passing a table to `require("claudehop").setup(opts)`.

local M = {}

M.defaults = {
  -- The Claude Code binary. We always drive the user's own install, so any
  -- new command, skill, or MCP server they add just works without changing
  -- this plugin.
  claude_cmd = "claude",

  -- Extra command-line arguments appended when we start a session.
  -- Example: { "--permission-mode", "acceptEdits" } to auto-accept edits.
  extra_args = {},

  -- Ask the engine for partial text events so replies stream in as they are
  -- written instead of arriving all at once.
  include_partial_messages = true,

  layout = {
    position = "right", -- the Claude column sits on the right of the editor
    width = 0.42,       -- fraction of total columns the Claude column takes
    input_height = 6,   -- height in lines of the prompt box at the bottom
  },

  keymaps = {
    -- In the conversation buffer (normal mode):
    jump = "<CR>",        -- jump to the file/symbol under the cursor
    next_ref = "<Tab>",   -- move cursor to the next reference
    prev_ref = "<S-Tab>", -- move cursor to the previous reference
    hop = "f",            -- label every visible reference, then jump to one by key

    -- In the prompt box:
    submit = "<CR>",      -- normal mode: send the prompt
    submit_insert = "<C-s>", -- insert mode: send the prompt

    -- Available in both buffers:
    new_session = "<C-n>",
    next_session = "<C-l>",
    prev_session = "<C-h>",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  return M.options
end

return M
