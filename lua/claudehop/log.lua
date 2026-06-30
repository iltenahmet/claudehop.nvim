-- A small in-memory log of everything that crosses the wire to and from the
-- Claude Code process. Use :ClaudeHopLog to view it when something looks wrong.

local M = {}

M.lines = {}     -- ring buffer of log lines
M.max = 2000     -- keep at most this many lines
M.enabled = true -- set vim.g.claudehop_debug = false to silence

local function timestamp()
  return os.date("%H:%M:%S")
end

-- Record one entry. `tag` is a short label like "out", "in", "err", "info".
function M.add(tag, text)
  if vim.g.claudehop_debug == false then
    return
  end
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    table.insert(M.lines, ("%s [%-4s] %s"):format(timestamp(), tag, line))
  end
  while #M.lines > M.max do
    table.remove(M.lines, 1)
  end
end

-- Open the log in a scratch buffer.
function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "claudehoplog"
  local lines = #M.lines > 0 and M.lines or { "(log is empty)" }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { #lines, 0 })
end

function M.clear()
  M.lines = {}
end

return M
