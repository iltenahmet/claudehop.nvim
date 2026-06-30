-- Manages Claude Code sessions. Each session is one running `claude` process
-- with its own conversation buffer and prompt box. Switching sessions just
-- swaps which buffers the panel windows show.

local M = {}
local config = require("claudehop.config")
local stream = require("claudehop.stream")

M.sessions = {}    -- list of live sessions
M.active_idx = nil -- index into M.sessions of the visible session
M.counter = 0      -- ever-increasing id used for unique buffer names

local function make_buf(name, filetype, modifiable)
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "hide"
  vim.bo[b].swapfile = false
  vim.bo[b].filetype = filetype
  vim.bo[b].modifiable = modifiable
  pcall(vim.api.nvim_buf_set_name, b, name)
  return b
end

-- Start a new session and make it the active one.
function M.create()
  local cfg = config.options
  M.counter = M.counter + 1
  local n = M.counter

  local sess = {
    n = n,
    conv_buf = make_buf("claudehop://chat/" .. n, "claudehop", false),
    input_buf = make_buf("claudehop://prompt/" .. n, "claudehop-input", true),
    ref_targets = {}, -- extmark id -> { file, line?, search? }
    busy = false,
  }

  local args = {
    "--print",
    "--input-format", "stream-json",
    "--output-format", "stream-json",
    "--verbose",
  }
  if cfg.include_partial_messages then
    table.insert(args, "--include-partial-messages")
  end
  if cfg.model then
    vim.list_extend(args, { "--model", cfg.model })
  end
  vim.list_extend(args, cfg.extra_args or {})

  local render = require("claudehop.render")
  sess.job = stream.spawn(cfg.claude_cmd, args, vim.fn.getcwd(),
    function(ev)
      vim.schedule(function()
        render.on_event(sess, ev)
      end)
    end,
    function(code)
      vim.schedule(function()
        render.on_exit(sess, code)
      end)
    end
  )

  require("claudehop.keymaps").attach(sess)
  table.insert(M.sessions, sess)
  M.active_idx = #M.sessions
  return sess
end

function M.active()
  if M.active_idx and M.sessions[M.active_idx] then
    return M.sessions[M.active_idx]
  end
  return nil
end

-- Return the active session, creating the first one if none exist yet.
function M.ensure()
  return M.active() or M.create()
end

-- Send a user turn to a session and mark it busy.
function M.send(sess, text)
  if not sess or text == "" then
    return
  end
  stream.send(sess.job, text)
  require("claudehop.render").set_status(sess, true)
end

-- Read the prompt box, send it, echo it into the conversation, and clear it.
function M.submit(sess)
  local lines = vim.api.nvim_buf_get_lines(sess.input_buf, 0, -1, false)
  local text = vim.trim(table.concat(lines, "\n"))
  if text == "" then
    return
  end
  vim.api.nvim_buf_set_lines(sess.input_buf, 0, -1, false, { "" })
  require("claudehop.render").append_prompt(sess, text)
  M.send(sess, text)
end

-- Switch the visible session by an offset (dir = 1 next, -1 previous).
function M.switch(dir)
  if #M.sessions == 0 then
    return
  end
  M.active_idx = ((M.active_idx - 1 + dir) % #M.sessions) + 1
  require("claudehop.ui").show(M.active())
end

return M
